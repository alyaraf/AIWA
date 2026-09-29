import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { Tag, InlineBanner, Status, RolePill } from "../App.jsx";

/**
 * Tiny display components used everywhere. They look trivial but a broken
 * className here silently drops the intended colour tone across the whole
 * app — worth pinning the contracts callers depend on.
 */

describe("<Tag>", () => {
  it("renders its children", () => {
    render(<Tag>Suspended</Tag>);
    expect(screen.getByText("Suspended")).toBeInTheDocument();
  });

  it("applies the tone class so styling works — defaults to plum when no tone given", () => {
    const { container } = render(<Tag>Default</Tag>);
    expect(container.firstChild).toHaveClass("tag-pill", "plum");
  });

  it("passes the tone through when explicitly set", () => {
    const { container } = render(<Tag tone="danger">Danger</Tag>);
    expect(container.firstChild).toHaveClass("tag-pill", "danger");
  });
});

describe("<InlineBanner>", () => {
  it("renders body without a title when only body is provided", () => {
    render(<InlineBanner body="Just some info" />);
    expect(screen.getByText("Just some info")).toBeInTheDocument();
    // No <strong> when title is absent — otherwise the empty bold node
    // pushes layout around for no reason.
    expect(screen.queryByRole("strong")).toBeNull();
  });

  it("renders title alongside body when both are given", () => {
    render(<InlineBanner tone="warn" title="Heads up" body="Something to watch" />);
    expect(screen.getByText("Heads up")).toBeInTheDocument();
    expect(screen.getByText("Something to watch")).toBeInTheDocument();
  });

  it("passes the tone through as a class so warn/danger visually differ", () => {
    const { container } = render(<InlineBanner tone="danger" body="Bad" />);
    expect(container.firstChild).toHaveClass("inline-banner", "danger");
  });
});

describe("<Status>", () => {
  it("normalises the status text to a friendly label", () => {
    render(<Status status="IN_PROGRESS" />);
    // The prettyStatus fallback title-cases and replaces underscores. Whether
    // the label is a known one or falls through, snake-case IN_PROGRESS
    // should never appear literally in the UI.
    expect(screen.queryByText("IN_PROGRESS")).toBeNull();
  });

  it("uses the lowercased status as a class for CSS styling hooks", () => {
    const { container } = render(<Status status="COMPLETED" />);
    expect(container.firstChild).toHaveClass("status", "completed");
  });

  it("survives a null / undefined status without crashing", () => {
    // Backend can send a legitimately unknown status during a flow addition.
    // A silent render (with an empty label) is better than an unhandled
    // exception that whites out the whole table row.
    expect(() => render(<Status status={null} />)).not.toThrow();
    expect(() => render(<Status status={undefined} />)).not.toThrow();
  });
});

describe("<RolePill>", () => {
  it("shouts the role in uppercase for at-a-glance identification", () => {
    render(<RolePill role="admin" />);
    expect(screen.getByText("ADMIN")).toBeInTheDocument();
  });

  it("puts a distinct class per role so admin / provider / customer look different", () => {
    const { container: a } = render(<RolePill role="ADMIN" />);
    const { container: p } = render(<RolePill role="PROVIDER" />);
    const { container: c } = render(<RolePill role="CUSTOMER" />);
    expect(a.firstChild).toHaveClass("role-pill", "admin");
    expect(p.firstChild).toHaveClass("role-pill", "provider");
    expect(c.firstChild).toHaveClass("role-pill", "customer");
  });

  it("falls back to the customer style for any unknown role rather than throwing", () => {
    const { container } = render(<RolePill role="GHOST" />);
    expect(container.firstChild).toHaveClass("role-pill", "customer");
  });
});
