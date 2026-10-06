package com.aiwa.repository;

import com.aiwa.entity.User;
import com.aiwa.enums.UserRole;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByEmail(String email);
    Optional<User> findByPhone(String phone);
    Optional<User> findByEmailIgnoreCase(String email);
    boolean existsByEmailIgnoreCase(String email);

    /**
     * The account a sign-in identifier names (V-01): an email when it contains
     * "@", otherwise a phone number. Never tries one as the other, so an email
     * set to someone's phone number cannot capture their sign-in.
     */
    default Optional<User> findByLogin(String identifier) {
        if (identifier == null || identifier.isBlank()) return Optional.empty();
        String v = identifier.trim();
        return com.aiwa.util.Identifiers.isEmail(v)
                ? findByEmailIgnoreCase(v)
                : findByPhone(com.aiwa.util.Identifiers.normalizePhone(v));
    }

    // ── Sign-in attempt limit (CR-01) ────────────────────────────────────────
    // Counted here, in the database, so it holds while Redis is down. Each is one
    // UPDATE: parallel guesses cannot pass the cap, and @Version is not bumped, so
    // a guess never makes the account owner's own save fail with 409.

    /**
     * Takes one of the account's sign-in attempts, before the password or code is
     * looked at. Returns 0 when there is none left: {@code max} attempts were
     * used and the last one is newer than {@code lockStart} (now minus the lock
     * period). Once the lock period has passed the count starts again at 1.
     * Its own transaction: the attempt stays counted when the caller's rolls back.
     */
    @org.springframework.data.jpa.repository.Modifying
    @org.springframework.transaction.annotation.Transactional(
            propagation = org.springframework.transaction.annotation.Propagation.REQUIRES_NEW)
    @Query("UPDATE User u SET u.lastFailedLoginAt = :now, u.failedLoginAttempts = " +
           "CASE WHEN u.failedLoginAttempts >= :max THEN 1 ELSE u.failedLoginAttempts + 1 END " +
           "WHERE u.id = :id AND (u.failedLoginAttempts < :max OR u.lastFailedLoginAt IS NULL " +
           "OR u.lastFailedLoginAt <= :lockStart)")
    int claimLoginAttempt(@Param("id") Long id, @Param("max") int max,
                          @Param("now") java.time.Instant now, @Param("lockStart") java.time.Instant lockStart);

    /** Gives one attempt back: the password was right and only the 2FA code is still due. */
    @org.springframework.data.jpa.repository.Modifying
    @org.springframework.transaction.annotation.Transactional
    @Query("UPDATE User u SET u.failedLoginAttempts = u.failedLoginAttempts - 1 " +
           "WHERE u.id = :id AND u.failedLoginAttempts > 0")
    int releaseLoginAttempt(@Param("id") Long id);

    /** A completed sign-in (or a password reset) starts the count again. */
    @org.springframework.data.jpa.repository.Modifying
    @org.springframework.transaction.annotation.Transactional
    @Query("UPDATE User u SET u.failedLoginAttempts = 0 WHERE u.id = :id AND u.failedLoginAttempts > 0")
    int clearLoginAttempts(@Param("id") Long id);

    /** Marks a TOTP time step as used. Returns 0 when that step, or a later one, was already used. */
    @org.springframework.data.jpa.repository.Modifying
    @org.springframework.transaction.annotation.Transactional
    @Query("UPDATE User u SET u.totpLastUsedStep = :step WHERE u.id = :id " +
           "AND (u.totpLastUsedStep IS NULL OR u.totpLastUsedStep < :step)")
    int claimTotpStep(@Param("id") Long id, @Param("step") long step);

    // ── 2FA enrollment (SEC-03) ──────────────────────────────────────────────

    /** Opens a pending enrollment: a fresh guess budget and an expiry. Call after the new secret is saved. */
    @org.springframework.data.jpa.repository.Modifying
    @org.springframework.transaction.annotation.Transactional
    @Query("UPDATE User u SET u.totpEnrollmentExpiresAt = :expiresAt, u.totpEnrollmentAttempts = 0 WHERE u.id = :id")
    int openTotpEnrollment(@Param("id") Long id, @Param("expiresAt") java.time.Instant expiresAt);

    /**
     * Takes one confirmation attempt from the pending enrollment, before the code is looked at.
     * Returns 0 when there is no live enrollment, the account already has 2FA on, or the budget
     * is used up. Its own transaction: the attempt stays counted when the caller's rolls back.
     */
    @org.springframework.data.jpa.repository.Modifying
    @org.springframework.transaction.annotation.Transactional(
            propagation = org.springframework.transaction.annotation.Propagation.REQUIRES_NEW)
    @Query("UPDATE User u SET u.totpEnrollmentAttempts = u.totpEnrollmentAttempts + 1 WHERE u.id = :id " +
           "AND u.totpEnabled = false AND u.totpEnrollmentExpiresAt > :now AND u.totpEnrollmentAttempts < :max")
    int claimTotpEnrollmentAttempt(@Param("id") Long id, @Param("max") int max, @Param("now") java.time.Instant now);

    /**
     * Completes the enrollment exactly once: turns 2FA on, ends earlier sessions and closes the
     * enrollment. Returns 0 if it was already completed, expired or cancelled in the meantime.
     */
    @org.springframework.data.jpa.repository.Modifying
    @org.springframework.transaction.annotation.Transactional
    @Query("UPDATE User u SET u.totpEnabled = true, u.tokensValidAfter = :cutoff, " +
           "u.totpEnrollmentExpiresAt = NULL, u.totpEnrollmentAttempts = 0 WHERE u.id = :id " +
           "AND u.totpEnabled = false AND u.totpSecret IS NOT NULL AND u.totpEnrollmentExpiresAt > :now")
    int completeTotpEnrollment(@Param("id") Long id, @Param("cutoff") java.time.Instant cutoff,
                               @Param("now") java.time.Instant now);

    /** Ends a pending enrollment whose budget is used up: the secret is discarded, so setup must start again. */
    @org.springframework.data.jpa.repository.Modifying
    @org.springframework.transaction.annotation.Transactional(
            propagation = org.springframework.transaction.annotation.Propagation.REQUIRES_NEW)
    @Query("UPDATE User u SET u.totpEnrollmentExpiresAt = NULL WHERE u.id = :id AND u.totpEnabled = false")
    int closeTotpEnrollment(@Param("id") Long id);

    long countByRoleAndCreatedAtBetween(UserRole role, java.time.LocalDateTime from, java.time.LocalDateTime to);
    boolean existsByEmail(String email);
    boolean existsByPhone(String phone);
    long countByRole(UserRole role);
    long countByRoleAndActive(UserRole role, boolean active);
    java.util.List<User> findByRoleAndActive(UserRole role, boolean active);

    @Query("SELECT COUNT(u) FROM User u JOIN u.adminPermissions p " +
           "WHERE u.role = com.aiwa.enums.UserRole.ADMIN AND u.active = true " +
           "AND p = com.aiwa.enums.AdminPermission.SUPER_ADMIN")
    long countActiveSuperAdmins();

    /** Row locks on every active super admin, held until commit: serialises changes that could remove the last one (DR-007). */
    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT u FROM User u JOIN u.adminPermissions p " +
           "WHERE u.role = com.aiwa.enums.UserRole.ADMIN AND u.active = true " +
           "AND p = com.aiwa.enums.AdminPermission.SUPER_ADMIN")
    java.util.List<User> lockActiveSuperAdmins();

    /** Row lock on one user until commit: serialises work that counts a customer's open bookings (SA-10). */
    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT u FROM User u WHERE u.id = :id")
    java.util.Optional<User> lockById(@org.springframework.data.repository.query.Param("id") Long id);

    Page<User> findByRoleOrderByCreatedAtDesc(UserRole role, Pageable pageable);

    /**
     * Admin Users screen (OPS-8): role filter and search combine, newest first.
     * pattern is "%" for no search, else "%term%" in lower case.
     */
    @Query("SELECT u FROM User u WHERE (:role IS NULL OR u.role = :role) AND (:pattern = '%' " +
           "OR LOWER(u.fullName) LIKE :pattern OR LOWER(u.email) LIKE :pattern OR u.phone LIKE :pattern) " +
           "ORDER BY u.createdAt DESC")
    Page<User> adminSearch(@Param("role") UserRole role, @Param("pattern") String pattern, Pageable pageable);

    Page<User> findByActiveOrderByCreatedAtDesc(boolean active, Pageable pageable);
}
