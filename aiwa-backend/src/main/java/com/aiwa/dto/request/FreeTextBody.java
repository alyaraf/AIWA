package com.aiwa.dto.request;

import com.aiwa.exception.BusinessException;

import java.util.HashMap;

/**
 * CR-21: free text (policy content, notes, reasons) travels in a JSON body, not
 * in the URL, where a long Arabic policy can pass the request-line limit and the
 * text lands in proxy and access logs. Field names match the old request
 * parameters, which stay accepted as a fallback so existing clients keep working.
 */
public class FreeTextBody extends HashMap<String, String> {

    /** The body's value for {@code key}, else the legacy request parameter. */
    public static String pick(FreeTextBody body, String key, String param) {
        String value = body == null ? null : body.get(key);
        return value != null ? value : param;
    }

    /**
     * {@code value} itself, or a translated 400 when it is longer than the column it is stored in: the text now
     * arrives in a body, so it is no longer cut short by the URL length and would fail the insert with a 500.
     */
    public static String bounded(String value, int max) {
        if (value != null && value.length() > max) throw new BusinessException("error.text_too_long");
        return value;
    }

    /** Like {@link #pick} for a field that used to be a required parameter. */
    public static String require(FreeTextBody body, String key, String param) {
        String value = pick(body, key, param);
        if (value == null) throw new BusinessException("Missing required field '" + key + "'");
        return value;
    }
}
