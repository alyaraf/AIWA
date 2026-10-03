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

    /** Like {@link #pick} for a field that used to be a required parameter. */
    public static String require(FreeTextBody body, String key, String param) {
        String value = pick(body, key, param);
        if (value == null) throw new BusinessException("Missing required field '" + key + "'");
        return value;
    }
}
