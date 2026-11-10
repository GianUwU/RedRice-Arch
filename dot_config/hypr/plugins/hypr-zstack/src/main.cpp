#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/render/types.hpp>
#include <hyprland/src/render/Context.hpp>
#include <hyprland/src/render/WindowRenderPresentation.hpp>
#include <hyprland/src/workspace/HLWorkspace.hpp>
#include <hyprland/src/desktop/view/window/Window.hpp>
#include <hyprland/src/desktop/view/window/WindowPresentation.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/desktop/state/ViewHitTester.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/state/WorkspaceState.hpp>
#include <hyprland/src/state/WorkspaceQuery.hpp>
#include <hyprland/src/state/MonitorState.hpp>
#include <hyprland/src/animation/WorkspaceAnimationController.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <dlfcn.h>
#include <vector>
#include <unordered_map>
#include <algorithm>

inline HANDLE PHANDLE = nullptr;
inline CHyprSignalListener g_workspaceActiveListener;
inline CHyprSignalListener g_workspaceRemovedListener;

using WORKSPACEID = uint32_t;
constexpr WORKSPACEID WORKSPACE_INVALID = 0;

typedef void (*origRenderWindow_t)(void* thisptr, Render::CRenderContext& ctx, PHLWINDOW pWindow, PHLMONITOR pMonitor, const Render::SWindowRenderPresentation& presentation, const Time::steady_tp& time, bool decorate, Render::eRenderPassMode mode, bool ignorePosition, bool standalone);
inline origRenderWindow_t origRenderWindow = nullptr;

typedef void (*origRenderWorkspaceWindows_t)(void* thisptr, Render::CRenderContext& ctx, PHLMONITOR pMonitor, PHLWORKSPACE pWorkspace, const Time::steady_tp& time, Render::eSceneMode mode);
inline origRenderWorkspaceWindows_t origRenderWorkspaceWindows = nullptr;
inline CFunctionHook* g_pRenderWorkspaceWindowsHook = nullptr;

typedef void (*origRenderWorkspaceWindowsFullscreen_t)(void* thisptr, Render::CRenderContext& ctx, PHLMONITOR pMonitor, PHLWORKSPACE pWorkspace, const Time::steady_tp& time, Render::eSceneMode mode);
inline origRenderWorkspaceWindowsFullscreen_t origRenderWorkspaceWindowsFullscreen = nullptr;
inline CFunctionHook* g_pRenderWorkspaceWindowsFullscreenHook = nullptr;

typedef void (*origStartAnimation_t)(PHLWORKSPACE ws, Animation::Workspace::eAnimationType type, bool left, bool instant, std::optional<std::string> style);
inline origStartAnimation_t origStartAnimation = nullptr;
inline CFunctionHook* g_pStartAnimationHook = nullptr;

typedef PHLWINDOW (*origWindowAt_t)(void* thisptr, const Vector2D& pos, uint16_t properties, PHLWINDOW ignoreWindow);
inline origWindowAt_t origWindowAt = nullptr;
inline CFunctionHook* g_pWindowAtHook = nullptr;

inline bool g_inRenderHook = false;
inline bool g_inAnimHook   = false;

struct SMonitorStack {
    // Workspaces in stack from bottom (index 0) to top (back)
    std::vector<WORKSPACEID> stack;
};

inline std::unordered_map<MONITORID, SMonitorStack> g_mMonitorStacks;

static WORKSPACEID getWorkspaceId(PHLWORKSPACE ws) {
    if (!ws)
        return WORKSPACE_INVALID;
    auto num = ws->numberedID();
    if (num.has_value())
        return *num;
    return WORKSPACE_INVALID;
}

static PHLWORKSPACE getWorkspace(WORKSPACEID id) {
    if (id == WORKSPACE_INVALID)
        return nullptr;
    return State::workspaceState()->query().numbered(::Workspace::SWorkspaceNumberedID(id)).run();
}

static PHLMONITOR getMonitor(MONITORID monId) {
    for (auto const& mon : State::monitorState()->monitors()) {
        if (mon && mon->m_id == monId)
            return mon;
    }
    return nullptr;
}

static SMonitorStack& getStackForMonitor(MONITORID monId) {
    return g_mMonitorStacks[monId];
}

constexpr size_t MAX_ZSTACK_DEPTH = 5;

struct SWorkspaceVisibilityGuard {
    std::vector<PHLWORKSPACE> hidden;

    SWorkspaceVisibilityGuard() {
        for (auto const& mon : State::monitorState()->monitors()) {
            if (!mon)
                continue;

            WORKSPACEID activeId  = getWorkspaceId(mon->m_activeWorkspace);
            WORKSPACEID specialId = getWorkspaceId(mon->m_activeSpecialWorkspace);

            for (auto const& ws : State::workspaceState()->workspacesCopy()) {
                if (!ws)
                    continue;
                if (ws->m_monitor.lock() == mon && getWorkspaceId(ws) != activeId && getWorkspaceId(ws) != specialId) {
                    if (ws->visible()) {
                        ws->setVisible(false);
                        hidden.push_back(ws);
                    }
                }
            }
        }
    }

    ~SWorkspaceVisibilityGuard() {
        for (auto& ws : hidden) {
            if (ws)
                ws->setVisible(true);
        }
    }
};

PHLWINDOW hkWindowAt(void* thisptr, const Vector2D& pos, uint16_t properties, PHLWINDOW ignoreWindow) {
    if (!origWindowAt)
        return nullptr;

    PHLWINDOW w = nullptr;
    {
        SWorkspaceVisibilityGuard guard;
        w = origWindowAt(thisptr, pos, properties, ignoreWindow);
    }

    if (!w)
        return nullptr;

    if (w->m_state & Desktop::View::WINDOW_STATE_PINNED)
        return w;

    auto ws = w->m_workspace;
    if (!ws)
        return w;

    auto pMonitor = State::monitorState()->query().vec(pos).run();
    if (!pMonitor)
        pMonitor = w->m_monitor.lock();
    if (!pMonitor)
        pMonitor = ws->m_monitor.lock();
    if (!pMonitor)
        return w;

    if (ws->type() == Workspace::eWorkspaceType::SPECIAL) {
        if (pMonitor->m_activeSpecialWorkspace == ws)
            return w;
        return nullptr;
    }

    if (pMonitor->m_activeWorkspace != ws)
        return nullptr;

    return w;
}

static bool isWorkspaceEmpty(PHLWORKSPACE pWorkspace) {
    if (!pWorkspace)
        return true;

    for (auto const& w : Desktop::windowState()->windows()) {
        if (!validMapped(w) || w->isHidden() || w->m_workspace != pWorkspace)
            continue;
        return false;
    }
    return true;
}

static void pruneStack(MONITORID monId, WORKSPACEID activeWsId) {
    auto& mStack = getStackForMonitor(monId);
    auto pMon = getMonitor(monId);

    // 1. Deduplicate stack preserving order (keeping latest occurrence)
    std::vector<WORKSPACEID> deduped;
    for (auto it = mStack.stack.rbegin(); it != mStack.stack.rend(); ++it) {
        if (std::find(deduped.begin(), deduped.end(), *it) == deduped.end()) {
            deduped.push_back(*it);
        }
    }
    std::reverse(deduped.begin(), deduped.end());
    mStack.stack = std::move(deduped);

    // 2. Remove empty or monitor-migrated workspaces (except active)
    for (auto it = mStack.stack.begin(); it != mStack.stack.end();) {
        if (*it == activeWsId) {
            ++it;
            continue;
        }
        auto ws = getWorkspace(*it);
        if (!ws || (pMon && ws->m_monitor.lock() != pMon) || isWorkspaceEmpty(ws)) {
            if (ws) {
                ws->m_forceRendering = false;
                ws->setVisible(false);
            }
            it = mStack.stack.erase(it);
        } else {
            ++it;
        }
    }

    // 3. Enforce 5-workspace stack limit: trim oldest from bottom of stack
    while (mStack.stack.size() > MAX_ZSTACK_DEPTH) {
        WORKSPACEID oldestId = mStack.stack.front();
        if (oldestId == activeWsId && mStack.stack.size() > 1) {
            oldestId = mStack.stack[1];
            mStack.stack.erase(mStack.stack.begin() + 1);
        } else {
            mStack.stack.erase(mStack.stack.begin());
        }

        auto oldWs = getWorkspace(oldestId);
        if (oldWs && oldestId != activeWsId) {
            oldWs->m_forceRendering = false;
            oldWs->setVisible(false);
        }
    }
}

static void renderWindowsForWorkspace(void* thisptr, Render::CRenderContext& ctx, PHLMONITOR pMonitor, PHLWORKSPACE pWorkspace, const Time::steady_tp& now, Render::eSceneMode mode) {
    if (!thisptr || !pWorkspace || !pMonitor || !origRenderWindow)
        return;

    // Fast O(1) fullscreen lookup
    PHLWINDOW fullscreenWindow = Fullscreen::controller()->hasFullscreen(pWorkspace) ? Fullscreen::controller()->getFullscreenWindow(pWorkspace) : nullptr;

    if (fullscreenWindow) {
        // Render fullscreen window with decorate = true so no black background pass is drawn
        origRenderWindow(thisptr, ctx, fullscreenWindow, pMonitor, fullscreenWindow->presentation().renderPresentation(mode), now, true, Render::RENDER_PASS_ALL, false, false);

        // Render floating windows over fullscreen
        for (auto const& w : Desktop::windowState()->windows()) {
            if (!validMapped(w) || w->isHidden() || w->m_workspace != pWorkspace)
                continue;
            if (!w->isFloating() || !w->shouldRenderOverFullscreen() || Fullscreen::controller()->isFullscreen(w))
                continue;
            origRenderWindow(thisptr, ctx, w, pMonitor, w->presentation().renderPresentation(mode), now, true, Render::RENDER_PASS_ALL, false, false);
        }
        return;
    }

    // Partition windows for this workspace in a single scan instead of 3 scans
    std::vector<PHLWINDOW> tiled;
    std::vector<PHLWINDOW> floating;
    for (auto const& w : Desktop::windowState()->windows()) {
        if (!validMapped(w) || w->isHidden() || w->m_workspace != pWorkspace)
            continue;
        if (w->m_state & Desktop::View::WINDOW_STATE_PINNED)
            continue;
        if (w->isFloating())
            floating.push_back(w);
        else
            tiled.push_back(w);
    }

    // 1. Tiled main pass
    for (auto const& w : tiled) {
        origRenderWindow(thisptr, ctx, w, pMonitor, w->presentation().renderPresentation(mode), now, true, Render::RENDER_PASS_MAIN, false, false);
    }

    // 2. Tiled popup pass
    for (auto const& w : tiled) {
        origRenderWindow(thisptr, ctx, w, pMonitor, w->presentation().renderPresentation(mode), now, true, Render::RENDER_PASS_POPUP, false, false);
    }

    // 3. Floating windows
    for (auto const& w : floating) {
        origRenderWindow(thisptr, ctx, w, pMonitor, w->presentation().renderPresentation(mode), now, true, Render::RENDER_PASS_ALL, false, false);
    }
}

static void renderStack(void* thisptr, Render::CRenderContext& ctx, PHLMONITOR pMonitor, PHLWORKSPACE pWorkspace, const Time::steady_tp& now, Render::eSceneMode mode) {
    MONITORID monId = pMonitor->m_id;
    auto& mStack = getStackForMonitor(monId);
    WORKSPACEID wsId = getWorkspaceId(pWorkspace);

    // Empty workspaces do not count towards the stack unless they are active/selected
    pruneStack(monId, wsId);

    // Ensure active workspace is at the top of the stack
    if (mStack.stack.empty() || mStack.stack.back() != wsId) {
        std::erase(mStack.stack, wsId);
        mStack.stack.push_back(wsId);
        pruneStack(monId, wsId);
    }

    // 1. Render stacked background workspaces (bottom to top, excluding active workspace)
    for (size_t i = 0; i < mStack.stack.size(); ++i) {
        WORKSPACEID id = mStack.stack[i];
        if (id == wsId)
            continue;

        auto ws = getWorkspace(id);
        if (!ws)
            continue;

        // Keep background workspaces stationary at (0, 0)
        if (ws->m_renderOffset->value() != Vector2D(0, 0) || ws->m_renderOffset->isBeingAnimated()) {
            *ws->m_renderOffset = Vector2D(0, 0);
            ws->m_renderOffset->warp();
        }
        if (ws->m_alpha->value() != 1.0f || ws->m_alpha->isBeingAnimated()) {
            *ws->m_alpha = 1.0f;
            ws->m_alpha->warp();
        }

        ws->m_forceRendering = true;
        ws->setVisible(true);
        renderWindowsForWorkspace(thisptr, ctx, pMonitor, ws, now, mode);
    }

    // 2. Render active workspace on top stationary at (0, 0)
    if (pWorkspace->m_renderOffset->value() != Vector2D(0, 0) || pWorkspace->m_renderOffset->isBeingAnimated()) {
        *pWorkspace->m_renderOffset = Vector2D(0, 0);
        pWorkspace->m_renderOffset->warp();
    }
    pWorkspace->m_forceRendering = true;
    pWorkspace->setVisible(true);

    renderWindowsForWorkspace(thisptr, ctx, pMonitor, pWorkspace, now, mode);
}

void hkRenderWorkspaceWindows(void* thisptr, Render::CRenderContext& ctx, PHLMONITOR pMonitor, PHLWORKSPACE pWorkspace, const Time::steady_tp& now, Render::eSceneMode mode) {
    if (g_inRenderHook || !pWorkspace || pWorkspace->type() == Workspace::eWorkspaceType::SPECIAL || !pMonitor) {
        origRenderWorkspaceWindows(thisptr, ctx, pMonitor, pWorkspace, now, mode);
        return;
    }

    g_inRenderHook = true;
    renderStack(thisptr, ctx, pMonitor, pWorkspace, now, mode);
    g_inRenderHook = false;
}

void hkRenderWorkspaceWindowsFullscreen(void* thisptr, Render::CRenderContext& ctx, PHLMONITOR pMonitor, PHLWORKSPACE pWorkspace, const Time::steady_tp& now, Render::eSceneMode mode) {
    if (g_inRenderHook || !pWorkspace || pWorkspace->type() == Workspace::eWorkspaceType::SPECIAL || !pMonitor) {
        origRenderWorkspaceWindowsFullscreen(thisptr, ctx, pMonitor, pWorkspace, now, mode);
        return;
    }

    g_inRenderHook = true;
    renderStack(thisptr, ctx, pMonitor, pWorkspace, now, mode);
    g_inRenderHook = false;
}

void hkStartAnimation(PHLWORKSPACE ws, Animation::Workspace::eAnimationType type, bool left, bool instant, std::optional<std::string> style) {
    if (g_inAnimHook || !ws || ws->type() == Workspace::eWorkspaceType::SPECIAL) {
        origStartAnimation(ws, type, left, instant, style);
        return;
    }

    auto pMonitor = ws->m_monitor.lock();
    if (!pMonitor) {
        origStartAnimation(ws, type, left, instant, style);
        return;
    }

    MONITORID monId = pMonitor->m_id;
    auto& mStack = getStackForMonitor(monId);
    auto pActiveWs = pMonitor->m_activeWorkspace;

    if (pActiveWs && pActiveWs->type() == Workspace::eWorkspaceType::SPECIAL) {
        origStartAnimation(ws, type, left, instant, style);
        return;
    }

    g_inAnimHook = true;

    WORKSPACEID targetId = getWorkspaceId(pActiveWs);
    WORKSPACEID wsId = getWorkspaceId(ws);

    if (type == Animation::Workspace::ANIMATION_TYPE_OUT) {
        // ws is being switched away from
        const bool wsEmpty = isWorkspaceEmpty(ws);
        if (wsEmpty) {
            // Empty workspace left behind: remove from stack
            std::erase(mStack.stack, wsId);
            ws->m_forceRendering = false;
            ws->setVisible(false);
        } else {
            // Workspace has windows: keep anchored at (0, 0)
            *ws->m_renderOffset = Vector2D(0, 0);
            ws->m_renderOffset->warp();
            *ws->m_alpha = 1.0f;
            ws->m_alpha->warp();
            ws->m_forceRendering = true;
            ws->setVisible(true);

            // Ensure ws is in the stack
            if (std::find(mStack.stack.begin(), mStack.stack.end(), wsId) == mStack.stack.end()) {
                mStack.stack.push_back(wsId);
            }
        }
        pruneStack(monId, targetId);
    } else {
        // ANIMATION_TYPE_IN: ws is incoming active/selected workspace
        // Move selected workspace to the top of the stack and show instantly at (0, 0)
        std::erase(mStack.stack, wsId);
        mStack.stack.push_back(wsId);

        *ws->m_renderOffset = Vector2D(0, 0);
        ws->m_renderOffset->warp();
        *ws->m_alpha = 1.0f;
        ws->m_alpha->warp();
        ws->m_forceRendering = true;
        ws->setVisible(true);

        pruneStack(monId, wsId);
    }

    g_inAnimHook = false;
}

static SDispatchResult dispatchRemoveFromStack(std::string args) {
    // Trim whitespace
    args.erase(0, args.find_first_not_of(" \t\n\r"));
    args.erase(args.find_last_not_of(" \t\n\r") + 1);

    WORKSPACEID removeId = WORKSPACE_INVALID;
    try {
        removeId = std::stoul(args);
    } catch (...) {
        auto ws = State::workspaceState()->query().address(args).run();
        if (ws)
            removeId = getWorkspaceId(ws);
    }

    if (removeId == WORKSPACE_INVALID) {
        return SDispatchResult{.passEvent = false, .success = false, .error = "Invalid workspace ID"};
    }

    for (auto& [monId, mStack] : g_mMonitorStacks) {
        auto it = std::find(mStack.stack.begin(), mStack.stack.end(), removeId);
        if (it != mStack.stack.end()) {
            mStack.stack.erase(it);

            auto ws = getWorkspace(removeId);
            if (ws) {
                ws->m_forceRendering = false;
                ws->setVisible(false);
            }

            for (auto& mon : State::monitorState()->monitors()) {
                if (mon && mon->m_id == monId) {
                    if (mon->m_activeWorkspace && getWorkspaceId(mon->m_activeWorkspace) == removeId) {
                        WORKSPACEID fallbackId = mStack.stack.empty() ? 1 : mStack.stack.back();
                        HyprlandAPI::invokeHyprctlCommand("dispatch", "workspace " + std::to_string(fallbackId));
                    } else if (g_pHyprRenderer) {
                        g_pHyprRenderer->damageMonitor(mon);
                    }
                }
            }
        }
    }

    return SDispatchResult{.passEvent = false, .success = true};
}

static SDispatchResult dispatchClearStack(std::string args) {
    for (auto& [monId, mStack] : g_mMonitorStacks) {
        auto pMon = getMonitor(monId);
        WORKSPACEID activeId = (pMon && pMon->m_activeWorkspace) ? getWorkspaceId(pMon->m_activeWorkspace) : WORKSPACE_INVALID;
        for (auto id : mStack.stack) {
            if (id != activeId) {
                auto ws = getWorkspace(id);
                if (ws) {
                    ws->m_forceRendering = false;
                    ws->setVisible(false);
                }
            }
        }
        mStack.stack.clear();
        if (activeId != WORKSPACE_INVALID) {
            mStack.stack.push_back(activeId);
        }
        if (pMon && g_pHyprRenderer) {
            g_pHyprRenderer->damageMonitor(pMon);
        }
    }
    return SDispatchResult{.passEvent = false, .success = true};
}

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    PHANDLE = handle;

    origRenderWindow = (origRenderWindow_t)dlsym(RTLD_DEFAULT, "_ZN6Render13IHyprRenderer12renderWindowERNS_14CRenderContextEN9Hyprutils6Memory14CSharedPointerIN7Desktop4View7CWindowEEENS5_IN7Monitor8CMonitorEEERKNS_25SWindowRenderPresentationERKNSt6chrono10time_pointINSG_3_V212steady_clockENSG_8durationIlSt5ratioILl1ELl1000000000EEEEEEbNS_15eRenderPassModeEbb");
    if (!origRenderWindow) {
        return {"hypr-zstack", "Failed dlsym renderWindow", "Gian", "2.0"};
    }

    void* fnRenderWindows = dlsym(RTLD_DEFAULT, "_ZN6Render13IHyprRenderer22renderWorkspaceWindowsERNS_14CRenderContextEN9Hyprutils6Memory14CSharedPointerIN7Monitor8CMonitorEEENS5_IN9Workspace12CHLWorkspaceEEERKNSt6chrono10time_pointINSC_3_V212steady_clockENSC_8durationIlSt5ratioILl1ELl1000000000EEEEEENS_10eSceneModeE");
    if (!fnRenderWindows) {
        return {"hypr-zstack", "Failed dlsym renderWorkspaceWindows", "Gian", "2.0"};
    }

    g_pRenderWorkspaceWindowsHook = HyprlandAPI::createFunctionHook(PHANDLE, fnRenderWindows, (void*)&hkRenderWorkspaceWindows);
    if (!g_pRenderWorkspaceWindowsHook || !g_pRenderWorkspaceWindowsHook->hook()) {
        return {"hypr-zstack", "Failed hook renderWorkspaceWindows", "Gian", "2.0"};
    }
    origRenderWorkspaceWindows = (origRenderWorkspaceWindows_t)g_pRenderWorkspaceWindowsHook->m_original;

    void* fnRenderWindowsFs = dlsym(RTLD_DEFAULT, "_ZN6Render13IHyprRenderer32renderWorkspaceWindowsFullscreenERNS_14CRenderContextEN9Hyprutils6Memory14CSharedPointerIN7Monitor8CMonitorEEENS5_IN9Workspace12CHLWorkspaceEEERKNSt6chrono10time_pointINSC_3_V212steady_clockENSC_8durationIlSt5ratioILl1ELl1000000000EEEEEENS_10eSceneModeE");
    if (!fnRenderWindowsFs) {
        return {"hypr-zstack", "Failed dlsym renderWorkspaceWindowsFullscreen", "Gian", "2.0"};
    }

    g_pRenderWorkspaceWindowsFullscreenHook = HyprlandAPI::createFunctionHook(PHANDLE, fnRenderWindowsFs, (void*)&hkRenderWorkspaceWindowsFullscreen);
    if (!g_pRenderWorkspaceWindowsFullscreenHook || !g_pRenderWorkspaceWindowsFullscreenHook->hook()) {
        return {"hypr-zstack", "Failed hook renderWorkspaceWindowsFullscreen", "Gian", "2.0"};
    }
    origRenderWorkspaceWindowsFullscreen = (origRenderWorkspaceWindowsFullscreen_t)g_pRenderWorkspaceWindowsFullscreenHook->m_original;

    void* fnAnim = dlsym(RTLD_DEFAULT, "_ZN9Animation9Workspace14startAnimationEN9Hyprutils6Memory14CSharedPointerIN9Workspace12CHLWorkspaceEEENS0_14eAnimationTypeEbbSt8optionalINSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEEE");
    if (!fnAnim) {
        return {"hypr-zstack", "Failed dlsym startAnimation", "Gian", "2.1"};
    }

    g_pStartAnimationHook = HyprlandAPI::createFunctionHook(PHANDLE, fnAnim, (void*)&hkStartAnimation);
    if (!g_pStartAnimationHook || !g_pStartAnimationHook->hook()) {
        return {"hypr-zstack", "Failed hook startAnimation", "Gian", "2.1"};
    }
    origStartAnimation = (origStartAnimation_t)g_pStartAnimationHook->m_original;

    void* fnWindowAt = dlsym(RTLD_DEFAULT, "_ZNK7Desktop14CViewHitTester8windowAtERKN9Hyprutils4Math8Vector2DEtNS1_6Memory14CSharedPointerINS_4View7CWindowEEE");
    if (!fnWindowAt) {
        return {"hypr-zstack", "Failed dlsym windowAt", "Gian", "2.1"};
    }

    g_pWindowAtHook = HyprlandAPI::createFunctionHook(PHANDLE, fnWindowAt, (void*)&hkWindowAt);
    if (!g_pWindowAtHook || !g_pWindowAtHook->hook()) {
        return {"hypr-zstack", "Failed hook windowAt", "Gian", "2.1"};
    }
    origWindowAt = (origWindowAt_t)g_pWindowAtHook->m_original;

    g_workspaceRemovedListener = Event::bus()->m_events.workspace.removed.listen([](PHLWORKSPACEREF wsRef) {
        auto ws = wsRef.lock();
        if (!ws)
            return;
        WORKSPACEID id = getWorkspaceId(ws);
        for (auto& [mon, mStack] : g_mMonitorStacks) {
            std::erase(mStack.stack, id);
        }
    });

    HyprlandAPI::addDispatcherV2(PHANDLE, "zstack:remove", &dispatchRemoveFromStack);
    HyprlandAPI::addDispatcherV2(PHANDLE, "zstack:clear", &dispatchClearStack);

    for (auto& mon : State::monitorState()->monitors()) {
        if (mon && mon->m_activeWorkspace) {
            auto& mStack = getStackForMonitor(mon->m_id);
            if (mStack.stack.empty())
                mStack.stack.push_back(getWorkspaceId(mon->m_activeWorkspace));
        }
    }

    g_workspaceActiveListener = Event::bus()->m_events.workspace.active.listen([](PHLWORKSPACE ws) {
        if (!ws || ws->type() == Workspace::eWorkspaceType::SPECIAL)
            return;

        auto pMonitor = ws->m_monitor.lock();
        if (!pMonitor)
            return;

        MONITORID monId = pMonitor->m_id;
        auto& mStack = getStackForMonitor(monId);
        WORKSPACEID wsId = getWorkspaceId(ws);

        // Move to top of stack
        std::erase(mStack.stack, wsId);
        mStack.stack.push_back(wsId);

        // Prune empty background workspaces & enforce stack depth
        pruneStack(monId, wsId);

        *ws->m_renderOffset = Vector2D(0, 0);
        ws->m_renderOffset->warp();
        *ws->m_alpha = 1.0f;
        ws->m_alpha->warp();
        ws->m_forceRendering = true;
        ws->setVisible(true);
    });

    return {"hypr-zstack", "Z-axis Workspace Stacking Plugin (Depth 5)", "Gian", "5.0"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    HyprlandAPI::removeDispatcher(PHANDLE, "zstack:remove");
    HyprlandAPI::removeDispatcher(PHANDLE, "zstack:clear");
    if (g_pRenderWorkspaceWindowsHook) {
        HyprlandAPI::removeFunctionHook(PHANDLE, g_pRenderWorkspaceWindowsHook);
    }
    if (g_pRenderWorkspaceWindowsFullscreenHook) {
        HyprlandAPI::removeFunctionHook(PHANDLE, g_pRenderWorkspaceWindowsFullscreenHook);
    }
    if (g_pStartAnimationHook) {
        HyprlandAPI::removeFunctionHook(PHANDLE, g_pStartAnimationHook);
    }
    if (g_pWindowAtHook) {
        HyprlandAPI::removeFunctionHook(PHANDLE, g_pWindowAtHook);
    }
    g_workspaceActiveListener.reset();
    g_workspaceRemovedListener.reset();

    for (auto& [mon, mStack] : g_mMonitorStacks) {
        for (auto id : mStack.stack) {
            auto ws = getWorkspace(id);
            if (ws) {
                ws->m_forceRendering = false;
                ws->setVisible(false);
            }
        }
    }

    g_mMonitorStacks.clear();
}
