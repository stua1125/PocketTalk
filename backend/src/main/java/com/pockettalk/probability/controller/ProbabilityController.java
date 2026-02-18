package com.pockettalk.probability.controller;

import com.pockettalk.common.dto.ApiResponse;
import com.pockettalk.probability.dto.ProbabilityRequest;
import com.pockettalk.probability.dto.ProbabilityResponse;
import com.pockettalk.probability.service.ProbabilityService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequiredArgsConstructor
public class ProbabilityController {

    private final ProbabilityService probabilityService;

    @PostMapping("/api/v1/probability/calculate")
    public ApiResponse<ProbabilityResponse> calculate(@Valid @RequestBody ProbabilityRequest request) {
        ProbabilityResponse response = probabilityService.calculate(request);
        return ApiResponse.ok(response);
    }
}
