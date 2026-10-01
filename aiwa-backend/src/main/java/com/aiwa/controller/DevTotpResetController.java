package com.aiwa.controller;

import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.User;
import com.aiwa.exception.BusinessException;
import com.aiwa.repository.UserRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Profile;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

/**
 * DEV-ONLY. Escape hatch for an account that's locked out of 2FA on a local
 * dev instance — the common case being the PC clock is out of sync with the
 * user's phone, so Google Authenticator's codes never match. Wipes the
 * account's TOTP secret and enabled flag; the user can then sign in with
 * just their password.
 *
 * Deliberately does NOT hand out valid codes. It only turns 2FA off so the
 * user can log in the plain way and either fix the clock or try setup again.
 *
 * Gated on the {@code local} Spring profile — this class isn't loaded at all
 * in {@code prod} / {@code default}, so the endpoint 404s in a real
 * deployment. Never mount this outside dev.
 */
@RestController
@RequestMapping("/dev/2fa")
@Profile("local")
@RequiredArgsConstructor
@Tag(name = "Dev — TOTP reset", description = "Local profile only. Wipes an account's 2FA state so a user locked out by clock skew can sign back in with just their password.")
public class DevTotpResetController {

    private final UserRepository userRepo;

    @PostMapping("/reset")
    @Transactional
    @Operation(summary = "Wipe 2FA for the account with this email/phone — local dev only, does not issue any code")
    public ResponseEntity<ApiResponse.Success<java.util.Map<String, Object>>> reset(
            @RequestParam String identifier) {
        User user = userRepo.findByLogin(identifier)
                .orElseThrow(() -> new BusinessException("No account for " + identifier));
        boolean was = user.isTotpEnabled();
        user.setTotpEnabled(false);
        user.setTotpSecret(null);
        userRepo.save(user);
        return ResponseEntity.ok(ApiResponse.Success.of(
                "2FA reset for " + identifier + (was ? " (was enabled)" : " (was already off)"),
                java.util.Map.of("identifier", identifier, "wasEnabled", was, "nowEnabled", false)
        ));
    }
}
