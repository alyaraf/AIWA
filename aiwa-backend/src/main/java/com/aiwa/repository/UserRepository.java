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
    java.util.List<User> findByPushToken(String pushToken);
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
