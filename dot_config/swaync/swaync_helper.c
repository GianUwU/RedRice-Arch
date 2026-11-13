#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/mman.h>
#include <link.h>
#include <dlfcn.h>
#include <gio/gio.h>
#include <gtk/gtk.h>

/*
 * SwayNC Helper Library
 * 1. Renames D-Bus name to org.freedesktop.NotificationsInternal so swaync_proxy can claim org.freedesktop.Notifications
 * 2. Keeps notification close button visible without requiring hover
 * 3. Patches out `list.move_to_beginning` inside `replace_notification` so multiple active notifications
 *    do not fight for the top position when updated by the countdown proxy or app updates.
 */

guint g_bus_own_name_on_connection_with_closures(
    GDBusConnection *connection,
    const gchar *name,
    GBusNameOwnerFlags flags,
    GClosure *name_acquired_closure,
    GClosure *name_lost_closure)
{
    static typeof(g_bus_own_name_on_connection_with_closures) *orig = NULL;
    if (!orig) orig = dlsym(RTLD_NEXT, "g_bus_own_name_on_connection_with_closures");
    if (name && strcmp(name, "org.freedesktop.Notifications") == 0) {
        name = "org.freedesktop.NotificationsInternal";
    }
    return orig(connection, name, flags, name_acquired_closure, name_lost_closure);
}

void gtk_revealer_set_child(GtkRevealer *revealer, GtkWidget *child) {
    static typeof(gtk_revealer_set_child) *orig = NULL;
    if (!orig) orig = dlsym(RTLD_NEXT, "gtk_revealer_set_child");
    orig(revealer, child);
    if (child && GTK_IS_BUTTON(child) && gtk_widget_has_css_class(child, "close-button")) {
        gtk_revealer_set_reveal_child(revealer, TRUE);
        gtk_widget_set_visible(GTK_WIDGET(revealer), TRUE);
        gtk_widget_set_valign(child, GTK_ALIGN_FILL);
        gtk_widget_set_halign(child, GTK_ALIGN_FILL);
        gtk_widget_set_valign(GTK_WIDGET(revealer), GTK_ALIGN_FILL);
        gtk_widget_set_halign(GTK_WIDGET(revealer), GTK_ALIGN_FILL);
        GtkWidget *parent = gtk_widget_get_parent(GTK_WIDGET(revealer));
        if (parent) {
            gtk_widget_set_visible(parent, TRUE);
            gtk_widget_set_valign(parent, GTK_ALIGN_FILL);
            gtk_widget_set_halign(parent, GTK_ALIGN_END);
        }
    }
}

void gtk_revealer_set_reveal_child(GtkRevealer *revealer, gboolean reveal_child) {
    static typeof(gtk_revealer_set_reveal_child) *orig = NULL;
    if (!orig) orig = dlsym(RTLD_NEXT, "gtk_revealer_set_reveal_child");
    GtkWidget *child = gtk_revealer_get_child(revealer);
    if (child && GTK_IS_BUTTON(child) && gtk_widget_has_css_class(child, "close-button")) {
        reveal_child = TRUE;
    }
    orig(revealer, reveal_child);
}

/*
 * Memory patch for SwayNC's `replace_notification`:
 * Disables `list.move_to_beginning (notification, true)` so replacing/updating a notification
 * keeps it in its existing place in the list, completely eliminating "fighting for the top".
 */
struct PhdrCallbackData {
    uintptr_t text_start;
    size_t text_len;
    int found;
};

static int phdr_callback(struct dl_phdr_info *info, size_t size, void *data) {
    (void)size;
    struct PhdrCallbackData *cb_data = (struct PhdrCallbackData *)data;

    /* Main executable has an empty name or ends with "swaync" */
    if (info->dlpi_name == NULL || info->dlpi_name[0] == '\0' || strstr(info->dlpi_name, "swaync")) {
        for (int i = 0; i < info->dlpi_phnum; i++) {
            if (info->dlpi_phdr[i].p_type == PT_LOAD && (info->dlpi_phdr[i].p_flags & PF_X)) {
                cb_data->text_start = info->dlpi_addr + info->dlpi_phdr[i].p_vaddr;
                cb_data->text_len = info->dlpi_phdr[i].p_memsz;
                cb_data->found = 1;
                return 1;
            }
        }
    }
    return 0;
}

__attribute__((constructor))
static void patch_swaync_replace_reorder(void) {
    struct PhdrCallbackData cb_data = {0, 0, 0};
    dl_iterate_phdr(phdr_callback, &cb_data);

    if (!cb_data.found || cb_data.text_len == 0) {
        return;
    }

    const uint8_t *start = (const uint8_t *)cb_data.text_start;
    size_t len = cb_data.text_len;

    /*
     * Pattern to search:
     * \x4c\x89\xfe               mov rsi, r15
     * \xba\x01\x00\x00\x00       mov edx, 1
     * \xe8 (4 bytes rel32)       call move_to_beginning
     * \x31\xff                   xor edi, edi
     */
    for (size_t i = 0; i + 15 <= len; i++) {
        if (start[i]   == 0x4c && start[i+1] == 0x89 && start[i+2] == 0xfe &&
            start[i+3] == 0xba && start[i+4] == 0x01 && start[i+5] == 0x00 &&
            start[i+6] == 0x00 && start[i+7] == 0x00 && start[i+8] == 0xe8 &&
            start[i+13] == 0x31 && start[i+14] == 0xff)
        {
            uint8_t *call_target = (uint8_t *)(start + i + 8);
            uintptr_t page_start = (uintptr_t)call_target & ~((uintptr_t)4095);
            size_t page_len = 4096;
            if (((uintptr_t)call_target + 5) > (page_start + page_len)) {
                page_len += 4096;
            }

            if (mprotect((void *)page_start, page_len, PROT_READ | PROT_WRITE | PROT_EXEC) == 0) {
                /* NOP out the 5-byte call instruction */
                for (int n = 0; n < 5; n++) {
                    call_target[n] = 0x90; /* nop */
                }
                mprotect((void *)page_start, page_len, PROT_READ | PROT_EXEC);
                g_message("[libswaync_helper] Successfully patched replace_notification to keep notification order stable.");
            } else {
                g_warning("[libswaync_helper] mprotect failed while patching replace_notification.");
            }
            break;
        }
    }
}
