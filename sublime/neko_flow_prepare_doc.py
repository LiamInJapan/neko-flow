import os

import sublime
import sublime_plugin


def _norm_path(p: str) -> str:
    p = os.path.expanduser(p)
    try:
        return os.path.normcase(os.path.realpath(p))
    except OSError:
        return os.path.normcase(os.path.abspath(p))


def _close_same_file_in_other_windows(path_norm: str, keep_window_id: int):
    """Drop tabs for this path everywhere except keep_window_id (shared buffer stays open)."""
    for win in sublime.windows():
        if win.id() == keep_window_id:
            continue
        for v in list(win.views()):
            fn = v.file_name()
            if fn and _norm_path(fn) == path_norm:
                v.close()


def _window_has_any_real_content(win):
    """True if the window still has a saved path, unsaved edits, or non-empty buffer."""
    for v in win.views():
        if v.file_name() is not None:
            return True
        if v.is_dirty():
            return True
        if v.size() > 0:
            return True
    return False


def _close_windows_that_are_only_empty(keep_window_id: int):
    """Close other top-level windows that are empty or only blank placeholder tabs (no ghost frame)."""
    for win in list(sublime.windows()):
        if win.id() == keep_window_id:
            continue
        if _window_has_any_real_content(win):
            continue
        try:
            win.run_command("close_window")
        except Exception:
            pass


class NekoFlowPrepareDocCommand(sublime_plugin.ApplicationCommand):
    """
    Open `path` in a fresh top-level window, then remove other tabs/views for that
    same file so it “breaks off” instead of duplicating. Uses Window.open_file (not
    set_view_index across windows, which does not move tabs in ST4). Any other
    window that only contained that file (or ends up as an empty placeholder) is
    closed so no ghost frame remains.

    Invoked from Hyprland flow via:
      subl --command 'neko_flow_prepare_doc {\"path\":\"...\"}'
    """

    def run(self, path=None):
        if not path:
            return
        path = os.path.expanduser(path)
        want = _norm_path(path)

        def _open_then_detach_others():
            sublime.run_command("new_window")
            w_new = sublime.active_window()
            keep_id = w_new.id()
            w_new.open_file(path)

            def _strip_old_tabs():
                _close_same_file_in_other_windows(want, keep_id)
                v = w_new.active_view()
                if v is not None:
                    w_new.focus_view(v)
                # Sublime may insert an empty tab after the last real tab closes; close that window on the next tick.
                sublime.set_timeout(lambda: _close_windows_that_are_only_empty(keep_id), 40)

            sublime.set_timeout(_strip_old_tabs, 75)

        sublime.set_timeout(_open_then_detach_others, 0)
