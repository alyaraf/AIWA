package com.aiwa.repository;

import com.aiwa.entity.SavedAddress;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface SavedAddressRepository extends JpaRepository<SavedAddress, Long> {
    List<SavedAddress> findByUserIdOrderByDefaultAddressDescCreatedAtDesc(Long userId);
}
