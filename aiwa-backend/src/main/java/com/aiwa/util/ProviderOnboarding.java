package com.aiwa.util;

import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.User;
import com.aiwa.enums.UserRole;

/**
 * The server's own record of how far a provider got through sign-up (audit M-05), derived from what is actually stored,
 * so the app can resume after a crash, a restart or a failed step instead of guessing from in-memory flags.
 * <ul>
 *   <li>{@code NO_PROFILE}: registered as a provider, no business profile yet</li>
 *   <li>{@code NEEDS_DOCUMENTS}: profile exists, but the ID photos or selfie have not all been uploaded</li>
 *   <li>{@code SUBMITTED}: everything is in; the verification status says what the admin decided</li>
 * </ul>
 * Null for anyone who is not a provider.
 */
public final class ProviderOnboarding {

    private ProviderOnboarding() {}

    public static String stageOf(User user, ProviderProfile profile) {
        if (user == null || user.getRole() != UserRole.PROVIDER) return null;
        if (profile == null) return "NO_PROFILE";
        boolean documents = notBlank(profile.getNationalIdFrontPath())
                && notBlank(profile.getNationalIdBackPath())
                && notBlank(profile.getSelfiePath());
        return documents ? "SUBMITTED" : "NEEDS_DOCUMENTS";
    }

    private static boolean notBlank(String s) {
        return s != null && !s.isBlank();
    }
}
