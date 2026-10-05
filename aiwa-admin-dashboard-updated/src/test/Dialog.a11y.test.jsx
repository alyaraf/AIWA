import React, { useState } from "react";
import { describe, it, expect, afterEach } from "vitest";
import { render, screen, fireEvent, within } from "@testing-library/react";
import { ModalFrame } from "../Dialog.jsx";
import { rowActivation } from "../App.jsx";

/** AD-11: dialogs are named, trap and restore focus, close on Escape and make the page behind them inert. */

function Host() {
  const [open, setOpen] = useState(false);
  const [inner, setInner] = useState(false);
  return (
    <div id="root">
      <button onClick={() => setOpen(true)}>Open dialog</button>
      <button>Behind</button>
      {open && (
        <ModalFrame label="Edit user" onClose={() => setOpen(false)}>
          <input aria-label="Name" />
          <button onClick={() => setInner(true)}>Delete</button>
          <button onClick={() => setOpen(false)}>Close</button>
          {inner && (
            <ModalFrame label="Really delete?" role="alertdialog" onClose={() => setInner(false)}>
              <button onClick={() => setInner(false)}>No</button>
              <button>Yes</button>
            </ModalFrame>
          )}
        </ModalFrame>
      )}
    </div>
  );
}

describe("ModalFrame", () => {
  afterEach(() => { document.getElementById("root")?.remove(); });

  function mount() {
    const root = document.createElement("div");
    root.id = "root";
    document.body.appendChild(root);
    return render(<Host />, { container: root.appendChild(document.createElement("div")) });
  }

  it("is a named modal dialog and moves focus inside", () => {
    mount();
    const opener = screen.getByRole("button", { name: "Open dialog" });
    opener.focus();
    fireEvent.click(opener);
    const dialog = screen.getByRole("dialog", { name: "Edit user" });
    expect(dialog).toHaveAttribute("aria-modal", "true");
    expect(dialog.contains(document.activeElement)).toBe(true);
  });

  it("makes the page behind it inert and restores everything on close, returning focus to the opener", () => {
    mount();
    const opener = screen.getByRole("button", { name: "Open dialog" });
    opener.focus();
    fireEvent.click(opener);
    expect(document.getElementById("root")).toHaveAttribute("inert");
    expect(document.getElementById("root")).toHaveAttribute("aria-hidden", "true");

    fireEvent.keyDown(document, { key: "Escape" });
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
    expect(document.getElementById("root")).not.toHaveAttribute("inert");
    expect(document.activeElement).toBe(opener);
  });

  it("keeps Tab inside the dialog in both directions", () => {
    mount();
    fireEvent.click(screen.getByRole("button", { name: "Open dialog" }));
    const dialog = screen.getByRole("dialog");
    const buttons = within(dialog).getAllByRole("button");
    const last = buttons[buttons.length - 1];
    const first = within(dialog).getByLabelText("Name");
    last.focus();
    fireEvent.keyDown(last, { key: "Tab" });
    expect(document.activeElement).toBe(first);
    first.focus();
    fireEvent.keyDown(first, { key: "Tab", shiftKey: true });
    expect(document.activeElement).toBe(last);
  });

  it("Escape closes only the topmost of two stacked dialogs and the page stays inert until the last one closes", () => {
    mount();
    fireEvent.click(screen.getByRole("button", { name: "Open dialog" }));
    fireEvent.click(screen.getByRole("button", { name: "Delete" }));
    expect(screen.getByRole("alertdialog", { name: "Really delete?" })).toBeInTheDocument();

    fireEvent.keyDown(document, { key: "Escape" });
    expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
    expect(screen.getByRole("dialog", { name: "Edit user" })).toBeInTheDocument();
    expect(document.getElementById("root")).toHaveAttribute("inert");

    fireEvent.keyDown(document, { key: "Escape" });
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
    expect(document.getElementById("root")).not.toHaveAttribute("inert");
  });

  it("a click on the backdrop closes it, a click inside does not", () => {
    mount();
    fireEvent.click(screen.getByRole("button", { name: "Open dialog" }));
    fireEvent.mouseDown(within(screen.getByRole("dialog")).getByLabelText("Name"));
    expect(screen.getByRole("dialog")).toBeInTheDocument();
    fireEvent.mouseDown(screen.getByRole("dialog").parentElement);
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  });
});

describe("rowActivation (keyboard rows)", () => {
  it("makes a row a focusable button activated by Enter and Space, with aria-expanded", () => {
    let clicks = 0;
    function Row() {
      const [open, setOpen] = useState(false);
      return <div data-testid="row" {...rowActivation(() => { clicks += 1; setOpen((o) => !o); }, open)}>row</div>;
    }
    render(<Row />);
    const row = screen.getByRole("button");
    expect(row).toHaveAttribute("tabindex", "0");
    expect(row).toHaveAttribute("aria-expanded", "false");
    fireEvent.keyDown(row, { key: "Enter" });
    expect(row).toHaveAttribute("aria-expanded", "true");
    fireEvent.keyDown(row, { key: " " });
    expect(row).toHaveAttribute("aria-expanded", "false");
    fireEvent.keyDown(row, { key: "a" });
    fireEvent.click(row);
    expect(clicks).toBe(3);
  });

  it("does not hijack the keys of a control inside the row", () => {
    let activated = 0;
    render(
      <div {...rowActivation(() => { activated += 1; })}>
        <button>inner</button>
      </div>
    );
    fireEvent.keyDown(screen.getByText("inner"), { key: "Enter" });
    expect(activated).toBe(0);
  });
});
