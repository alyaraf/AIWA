import React, { useEffect, useRef } from "react";
import { createPortal } from "react-dom";

// AD-11: one accessible modal primitive for every dialog of the dashboard.
//  - named (aria-label), role dialog / alertdialog, aria-modal
//  - focus moves into the dialog, Tab / Shift+Tab stay inside it, Escape closes the topmost one
//  - the rest of the page (#root) is inert while a dialog is open, so keyboard and screen-reader users cannot reach
//    controls behind it, and focus returns to the control that opened the dialog when it closes
// It renders into document.body (a portal) so that "everything else is inert" is simple and nested dialogs
// (a confirmation opened from an edit form) stack correctly.

const FOCUSABLE = [
  "a[href]", "button:not([disabled])", "input:not([disabled]):not([type=hidden])", "select:not([disabled])",
  "textarea:not([disabled])", "[tabindex]:not([tabindex='-1'])"
].join(",");

const stack = []; // open dialogs, last = topmost
let openCount = 0;

function setBackgroundInert(on) {
  const root = document.getElementById("root");
  if (!root) return;
  if (on) {
    root.setAttribute("inert", "");
    root.setAttribute("aria-hidden", "true");
  } else {
    root.removeAttribute("inert");
    root.removeAttribute("aria-hidden");
  }
}

function isVisible(el) {
  if (el.closest("[hidden]")) return false;
  const style = window.getComputedStyle(el);
  return style.display !== "none" && style.visibility !== "hidden";
}

export function ModalFrame({
  onClose, label, role = "dialog", backdropClassName = "", cardClassName = "", as: Card = "div", cardProps = {}, children
}) {
  const cardRef = useRef(null);
  const token = useRef({});
  const closeRef = useRef(onClose);
  closeRef.current = onClose;

  useEffect(() => {
    const opener = document.activeElement;
    const me = token.current;
    stack.push(me);
    openCount += 1;
    if (openCount === 1) setBackgroundInert(true);

    const card = cardRef.current;
    if (card && !card.contains(document.activeElement)) {
      const first = card.querySelector("[autofocus], [data-autofocus]") || card.querySelector(FOCUSABLE);
      (first || card).focus();
    }

    const onKey = (event) => {
      if (stack[stack.length - 1] !== me) return; // only the topmost dialog reacts
      if (event.key === "Escape") {
        event.stopPropagation();
        closeRef.current?.();
        return;
      }
      if (event.key !== "Tab" || !cardRef.current) return;
      const items = [...cardRef.current.querySelectorAll(FOCUSABLE)].filter(isVisible);
      if (items.length === 0) { event.preventDefault(); cardRef.current.focus(); return; }
      const firstItem = items[0];
      const lastItem = items[items.length - 1];
      const active = document.activeElement;
      if (event.shiftKey && (active === firstItem || !cardRef.current.contains(active))) {
        event.preventDefault();
        lastItem.focus();
      } else if (!event.shiftKey && (active === lastItem || !cardRef.current.contains(active))) {
        event.preventDefault();
        firstItem.focus();
      }
    };
    document.addEventListener("keydown", onKey, true);

    return () => {
      document.removeEventListener("keydown", onKey, true);
      const at = stack.indexOf(me);
      if (at >= 0) stack.splice(at, 1);
      openCount = Math.max(0, openCount - 1);
      if (openCount === 0) setBackgroundInert(false);
      if (opener && typeof opener.focus === "function" && document.contains(opener)) opener.focus();
    };
  }, []);

  return createPortal(
    <div
      className={`modal-backdrop ${backdropClassName}`.trim()}
      onMouseDown={(event) => { if (event.target === event.currentTarget) closeRef.current?.(); }}
    >
      <Card
        ref={cardRef}
        className={cardClassName}
        role={role}
        aria-modal="true"
        aria-label={label}
        tabIndex={-1}
        onMouseDown={(event) => event.stopPropagation()}
        {...cardProps}
      >
        {children}
      </Card>
    </div>,
    document.body
  );
}
