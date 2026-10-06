package com.aiwa.service.impl;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.util.Locale;
import java.util.Set;

/**
 * Some SMS / e-mail gateways answer HTTP 200 and report the refusal in the JSON body ({@code success:false},
 * {@code status:"failed"}, an {@code error} object). A bare 2xx is therefore not proof of acceptance (P-07);
 * this reads those fields. A body that is empty or not JSON is treated as accepted, as before.
 *
 * <p>Integration contract (R4 follow-up): when a gateway is known to return a message receipt (an id), configure its
 * location ({@code aiwa.sms.receipt-field} / {@code aiwa.email.receipt-field}, a dotted JSON path such as
 * {@code data.messageId}). With it set, a 2xx is accepted only when the body carries a non-blank value there; an
 * unreadable body or a missing receipt is reported like a refusal, so "accepted by HTTP" is no longer mistaken for
 * "accepted by the provider". Unset (the default) keeps the lenient behaviour above.
 */
final class GatewayRefusal {

    private static final ObjectMapper JSON = new ObjectMapper();
    private static final Set<String> FAILED_STATUSES =
            Set.of("error", "failed", "failure", "fail", "rejected", "refused", "undelivered");

    private GatewayRefusal() {}

    /**
     * Like {@link #of(String)}, and with a [receiptField] also demands the provider's receipt in the body.
     * Returns the reason the message must be treated as NOT accepted, or null when it is accepted.
     */
    static String of(String body, String receiptField) {
        String refusal = of(body);
        if (refusal != null || receiptField == null || receiptField.isBlank()) return refusal;
        if (body == null || body.isBlank()) return "no receipt: empty body";
        JsonNode node;
        try {
            node = JSON.readTree(body);
        } catch (Exception notJson) {
            return "no receipt: body is not JSON";
        }
        for (String part : receiptField.trim().split("\\.")) {
            node = node == null ? null : node.get(part);
        }
        if (node == null || node.isNull() || (node.isTextual() && node.asText().isBlank())
                || (node.isContainerNode() && node.isEmpty())) {
            return "no receipt: '" + receiptField.trim() + "' missing";
        }
        return null;
    }

    /** The reason a 2xx body reports a refusal, or null when it doesn't (or isn't JSON). */
    static String of(String body) {
        if (body == null || body.isBlank()) return null;
        JsonNode root;
        try {
            root = JSON.readTree(body);
        } catch (Exception notJson) {
            return null;
        }
        if (root == null || !root.isObject()) return null;
        for (String flag : new String[]{"success", "ok"}) {
            JsonNode v = root.get(flag);
            if (v != null && v.isBoolean() && !v.asBoolean()) return flag + "=false" + detail(root);
        }
        JsonNode status = root.get("status");
        if (status != null && status.isTextual()
                && FAILED_STATUSES.contains(status.asText().trim().toLowerCase(Locale.ROOT))) {
            return "status=" + status.asText() + detail(root);
        }
        JsonNode error = root.get("error");
        if (error != null && !error.isNull() && !(error.isTextual() && error.asText().isBlank())
                && !(error.isBoolean() && !error.asBoolean())) {
            return "error=" + truncate(error.toString());
        }
        return null;
    }

    private static String detail(JsonNode root) {
        for (String key : new String[]{"message", "error", "reason"}) {
            JsonNode v = root.get(key);
            if (v != null && !v.isNull()) return " (" + truncate(v.asText(v.toString())) + ")";
        }
        return "";
    }

    private static String truncate(String s) {
        return s.length() > 200 ? s.substring(0, 200) : s;
    }
}
