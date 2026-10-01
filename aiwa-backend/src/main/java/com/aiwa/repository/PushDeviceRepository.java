package com.aiwa.repository;

import com.aiwa.entity.PushDevice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface PushDeviceRepository extends JpaRepository<PushDevice, Long> {
    List<PushDevice> findByUserId(Long userId);

    Optional<PushDevice> findByToken(String token);

    @Modifying
    @Query("DELETE FROM PushDevice d WHERE d.token = :token")
    int deleteByToken(@Param("token") String token);

    @Modifying
    @Query("DELETE FROM PushDevice d WHERE d.user.id = :userId AND d.token = :token")
    int deleteByUserIdAndToken(@Param("userId") Long userId, @Param("token") String token);

    @Modifying
    @Query("DELETE FROM PushDevice d WHERE d.user.id = :userId")
    int deleteByUserId(@Param("userId") Long userId);
}
