package com.aiwa.service.impl;

import com.aiwa.entity.PushDevice;
import com.aiwa.entity.User;
import com.aiwa.enums.DevicePlatform;
import com.aiwa.repository.PushDeviceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * Push addresses per phone (R2-12). Before, each user had one token column: a
 * second phone replaced the first, and a phone shared by two accounts kept
 * getting the first account's notifications after the second signed in.
 */
@Service
@RequiredArgsConstructor
public class PushDeviceService {

    private final PushDeviceRepository repo;

    /** This phone now belongs to {@code user}; any other account's claim on it ends. */
    @Transactional
    public void register(User user, String token, DevicePlatform platform) {
        String t = token.trim();
        PushDevice device = repo.findByToken(t).orElseGet(() -> PushDevice.builder().token(t).build());
        device.setUser(user);
        device.setPlatform(platform);
        repo.save(device);
    }

    /** One phone (sign-out there), or every phone of the user when {@code token} is blank. */
    @Transactional
    public void unregister(User user, String token) {
        if (token == null || token.isBlank()) repo.deleteByUserId(user.getId());
        else repo.deleteByUserIdAndToken(user.getId(), token.trim());
    }

    @Transactional(readOnly = true)
    public List<PushDevice> devicesOf(Long userId) {
        return repo.findByUserId(userId);
    }

    /** FCM says the token is dead (app uninstalled, token rotated). */
    @Transactional
    public void forget(String token) {
        repo.deleteByToken(token);
    }
}
