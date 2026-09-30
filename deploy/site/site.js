// Public legal pages (OPS-4). Data comes from the same origin (/api/... is
// proxied to the backend by Caddy) and is always rendered with textContent.
(function () {
  "use strict";

  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }

  function getJson(path) {
    return fetch(path, { headers: { Accept: "application/json" } }).then(function (r) {
      if (!r.ok) throw new Error("HTTP " + r.status);
      return r.json();
    }).then(function (body) { return body && body.data; });
  }

  // terms.html: <section data-terms="CUSTOMER_TERMS"> etc.
  document.querySelectorAll("[data-terms]").forEach(function (box) {
    var type = box.getAttribute("data-terms");
    getJson("/api/terms/latest?type=" + encodeURIComponent(type)).then(function (t) {
      box.textContent = "";
      box.append(el("p", "muted", "Version " + t.version + (t.createdAt ? " · published " + String(t.createdAt).slice(0, 10) : "")));
      if (t.contentEn) box.append(el("div", "terms-body", t.contentEn));
      if (t.contentAr) {
        var ar = el("div", "terms-body", t.contentAr);
        ar.setAttribute("dir", "rtl");
        ar.setAttribute("lang", "ar");
        box.append(el("h2", null, "العربية"), ar);
      }
    }).catch(function () {
      box.textContent = "";
      box.append(el("p", "muted", "These terms could not be loaded right now. They are also shown in the app before you sign up."));
    });
  });

  // delete-account.html: fill in the live support contacts.
  var contact = document.getElementById("support-contact");
  if (contact) {
    getJson("/api/support/contact").then(function (s) {
      if (!s) return;
      contact.textContent = "";
      (s.numbers && s.numbers.length ? s.numbers : [{ number: s.whatsappNumber, displayNumber: s.whatsappNumberDisplay }])
        .filter(function (n) { return n && n.number; })
        .forEach(function (n) {
          var a = el("a", "btn", "WhatsApp " + (n.displayNumber || n.number));
          a.href = "https://wa.me/" + String(n.number).replace(/[^0-9]/g, "") + "?text=" + encodeURIComponent("Please delete my AIWA account. Phone/email on the account: ");
          a.rel = "noopener";
          contact.append(a);
        });
      if (s.supportEmail) {
        var m = el("a", "btn", "Email " + s.supportEmail);
        m.href = "mailto:" + s.supportEmail + "?subject=" + encodeURIComponent("Delete my AIWA account");
        contact.append(m);
      }
      if (s.availabilityHoursEn) contact.append(el("p", "muted", s.availabilityHoursEn));
    }).catch(function () { /* keep the fallback text */ });
  }
})();
