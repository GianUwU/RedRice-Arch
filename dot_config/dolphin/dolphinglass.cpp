#define _GNU_SOURCE
#include <dlfcn.h>
#include <QApplication>
#include <QColor>
#include <QPalette>
#include <QWidget>

static void applyGlobalPalette() {
    static bool applied = false;
    if (applied || !qApp) return;
    applied = true;

    QPalette pal = qApp->palette();
    QColor crimson(113, 4, 0);
    QColor crimsonDark(14, 12, 14);
    QColor white(255, 255, 255);
    QColor muted(200, 190, 195);
    QColor pinkAccent(185, 125, 140);

    for (int g = 0; g < 3; ++g) {
        QPalette::ColorGroup group = static_cast<QPalette::ColorGroup>(g);
        pal.setColor(group, QPalette::Window, crimsonDark);
        pal.setColor(group, QPalette::WindowText, white);
        pal.setColor(group, QPalette::Base, crimsonDark);
        pal.setColor(group, QPalette::AlternateBase, crimsonDark);
        pal.setColor(group, QPalette::Text, white);
        pal.setColor(group, QPalette::Button, crimsonDark);
        pal.setColor(group, QPalette::ButtonText, white);
        pal.setColor(group, QPalette::Highlight, crimson);
        pal.setColor(group, QPalette::HighlightedText, white);
        pal.setColor(group, QPalette::Link, pinkAccent);
        pal.setColor(group, QPalette::ToolTipBase, crimsonDark);
        pal.setColor(group, QPalette::ToolTipText, white);
        pal.setColor(group, QPalette::PlaceholderText, muted);
    }
    qApp->setPalette(pal);
}

extern "C" {

// 1. Disable alternating row backgrounds completely
bool _ZNK13KItemListView23useAlternateBackgroundsEv(void* this_ptr) {
    return false;
}

// 2. Force item filenames to 100% solid, crisp white
QColor _ZNK23KStandardItemListWidget9textColorERK7QWidget(void* this_ptr, const QWidget& view) {
    return QColor(255, 255, 255);
}

// 3. Force additional info (file size, timestamp, items count) to crisp light text
void _ZN23KStandardItemListWidget29updateAdditionalInfoTextColorEv(void* this_ptr) {
    if (!this_ptr) return;
    QColor* col = reinterpret_cast<QColor*>(reinterpret_cast<char*>(this_ptr) + 0x248);
    *col = QColor(215, 210, 215);
}

// 4. Force group header text color to pure white
QColor _ZNK20KItemListGroupHeader9textColorEv(void* this_ptr) {
    return QColor(255, 255, 255);
}

// 5. Enable native ARGB translucent visual on the top-level window
typedef void (*orig_setVisible_t)(QWidget* this_ptr, bool visible);

void _ZN7QWidget10setVisibleEb(QWidget* this_ptr, bool visible) {
    static orig_setVisible_t orig_setVisible = (orig_setVisible_t)dlsym(RTLD_NEXT, "_ZN7QWidget10setVisibleEb");
    if (visible && this_ptr) {
        applyGlobalPalette();
        if (this_ptr->isWindow()) {
            this_ptr->setAttribute(Qt::WA_TranslucentBackground, true);
        }
    }
    orig_setVisible(this_ptr, visible);
}

}
