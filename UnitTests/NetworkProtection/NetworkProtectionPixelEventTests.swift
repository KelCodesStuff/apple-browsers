//
//  NetworkProtectionPixelEventTests.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#if NETWORK_PROTECTION

import NetworkProtection
import PixelKit
import PixelKitTestingUtilities
import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class NetworkProtectionPixelEventTests: XCTestCase {

    private enum TestError: CustomNSError {
        case testError
        case underlyingError

        /// The domain of the error.
        static var errorDomain: String {
            "testDomain"
        }

        /// The error code within the given domain.
        var errorCode: Int {
            switch self {
            case .testError: return 1
            case .underlyingError: return 2
            }
        }

        /// The user-info dictionary.
        var errorUserInfo: [String: Any] {
            switch self {
            case .testError:
                return [NSUnderlyingErrorKey: TestError.underlyingError]
            case .underlyingError:
                return [:]
            }
        }
    }

    // MARK: - Test Firing Pixels

    /// This test verifies validates expectations when firing `NetworkProtectionPixelEvent`.
    ///
    /// This test verifies a few different things:
    ///  - That the pixel name is not changed by mistake.
    ///  - That when the pixel is fired its name and parameters are exactly what's expected.
    ///
    func testVPNPixelFireExpectations() {
        fire(NetworkProtectionPixelEvent.networkProtectionActiveUser,
             and: .expect(pixelName: "m_mac_netp_daily_active"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionNewUser,
             and: .expect(pixelName: "m_mac_netp_daily_active_u"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionControllerStartAttempt,
             and: .expect(pixelName: "m_mac_netp_controller_start_attempt"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionControllerStartFailure(TestError.testError),
             and: .expect(pixelName: "m_mac_netp_controller_start_failure",
                          error: TestError.testError,
                          underlyingErrors: [TestError.underlyingError]),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionControllerStartSuccess,
             and: .expect(pixelName: "m_mac_netp_controller_start_success"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionTunnelStartAttempt,
             and: .expect(pixelName: "m_mac_netp_tunnel_start_attempt"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionTunnelStartFailure(TestError.testError),
             and: .expect(pixelName: "m_mac_netp_tunnel_start_failure",
                          error: TestError.testError,
                          underlyingErrors: [TestError.underlyingError]),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionTunnelStartSuccess,
             and: .expect(pixelName: "m_mac_netp_tunnel_start_success"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionTunnelUpdateAttempt,
             and: .expect(pixelName: "m_mac_netp_tunnel_update_attempt"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionTunnelUpdateFailure(TestError.testError),
             and: .expect(pixelName: "m_mac_netp_tunnel_update_failure",
                          error: TestError.testError,
                          underlyingErrors: [TestError.underlyingError]),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionTunnelUpdateSuccess,
             and: .expect(pixelName: "m_mac_netp_tunnel_update_success"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionEnableAttemptConnecting,
             and: .expect(pixelName: "m_mac_netp_ev_enable_attempt"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionEnableAttemptSuccess,
             and: .expect(pixelName: "m_mac_netp_ev_enable_attempt_success"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionEnableAttemptFailure,
             and: .expect(pixelName: "m_mac_netp_ev_enable_attempt_failure"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionTunnelFailureDetected,
             and: .expect(pixelName: "m_mac_netp_ev_tunnel_failure"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionTunnelFailureRecovered,
             and: .expect(pixelName: "m_mac_netp_ev_tunnel_failure_recovered"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionLatency(quality: .excellent),
             and: .expect(pixelName: "m_mac_netp_ev_\(NetworkProtectionLatencyMonitor.ConnectionQuality.excellent.rawValue)_latency"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionLatencyError,
             and: .expect(pixelName: "m_mac_netp_ev_latency_error"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionTunnelConfigurationNoServerRegistrationInfo,
             and: .expect(pixelName: "m_mac_netp_tunnel_config_error_no_server_registration_info"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionTunnelConfigurationCouldNotSelectClosestServer,
             and: .expect(pixelName: "m_mac_netp_tunnel_config_error_could_not_select_closest_server"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionTunnelConfigurationCouldNotGetPeerPublicKey,
             and: .expect(pixelName: "m_mac_netp_tunnel_config_error_could_not_get_peer_public_key"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionTunnelConfigurationCouldNotGetPeerHostName,
             and: .expect(pixelName: "m_mac_netp_tunnel_config_error_could_not_get_peer_host_name"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionTunnelConfigurationCouldNotGetInterfaceAddressRange,
             and: .expect(pixelName: "m_mac_netp_tunnel_config_error_could_not_get_interface_address_range"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionClientFailedToFetchServerList(TestError.testError),
             and: .expect(pixelName: "m_mac_netp_backend_api_error_failed_to_fetch_server_list",
                          error: TestError.testError,
                          underlyingErrors: [TestError.underlyingError]),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionClientFailedToParseServerListResponse,
             and: .expect(pixelName: "m_mac_netp_backend_api_error_parsing_server_list_response_failed"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionClientFailedToEncodeRegisterKeyRequest,
             and: .expect(pixelName: "m_mac_netp_backend_api_error_encoding_register_request_body_failed"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionClientFailedToFetchRegisteredServers(TestError.testError),
             and: .expect(pixelName: "m_mac_netp_backend_api_error_failed_to_fetch_registered_servers",
                          error: TestError.testError,
                          underlyingErrors: [TestError.underlyingError]),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionClientFailedToParseRegisteredServersResponse,
             and: .expect(pixelName: "m_mac_netp_backend_api_error_parsing_device_registration_response_failed"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionClientFailedToEncodeRedeemRequest,
             and: .expect(pixelName: "m_mac_netp_backend_api_error_encoding_redeem_request_body_failed"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionClientInvalidInviteCode,
             and: .expect(pixelName: "m_mac_netp_backend_api_error_invalid_invite_code"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionClientFailedToRedeemInviteCode(TestError.testError),
             and: .expect(pixelName: "m_mac_netp_backend_api_error_failed_to_redeem_invite_code",
                          error: TestError.testError,
                          underlyingErrors: [TestError.underlyingError]),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionClientFailedToParseRedeemResponse(TestError.testError),
             and: .expect(pixelName: "m_mac_netp_backend_api_error_parsing_redeem_response_failed",
                          error: TestError.testError,
                          underlyingErrors: [TestError.underlyingError]),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionClientFailedToFetchLocations(TestError.testError),
             and: .expect(pixelName: "m_mac_netp_backend_api_error_failed_to_fetch_location_list",
                          error: TestError.testError,
                          underlyingErrors: [TestError.underlyingError]),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionClientFailedToParseLocationsResponse(TestError.testError),
             and: .expect(pixelName: "m_mac_netp_backend_api_error_parsing_location_list_response_failed",
                          error: TestError.testError,
                          underlyingErrors: [TestError.underlyingError]),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionClientInvalidAuthToken,
             and: .expect(pixelName: "m_mac_netp_backend_api_error_invalid_auth_token"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionKeychainErrorFailedToCastKeychainValueToData(field: "field"),
             and: .expect(pixelName: "m_mac_netp_keychain_error_failed_to_cast_keychain_value_to_data",
                          customFields: [
                            PixelKit.Parameters.keychainFieldName: "field",
                          ]),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionKeychainReadError(field: "field", status: 1),
             and: .expect(pixelName: "m_mac_netp_keychain_error_read_failed",
                          customFields: [
                            PixelKit.Parameters.keychainFieldName: "field",
                            PixelKit.Parameters.errorCode: "1",
                          ]),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionKeychainWriteError(field: "field", status: 1),
             and: .expect(pixelName: "m_mac_netp_keychain_error_write_failed",
                          customFields: [
                            PixelKit.Parameters.keychainFieldName: "field",
                            PixelKit.Parameters.errorCode: "1",
                          ]),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionKeychainUpdateError(field: "field", status: 1),
             and: .expect(pixelName: "m_mac_netp_keychain_error_update_failed",
                          customFields: [
                            PixelKit.Parameters.keychainFieldName: "field",
                            PixelKit.Parameters.errorCode: "1",
                          ]),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionKeychainDeleteError(status: 1),
             and: .expect(pixelName: "m_mac_netp_keychain_error_delete_failed",
                          customFields: [
                            PixelKit.Parameters.errorCode: "1"
                          ]),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionWireguardErrorCannotLocateTunnelFileDescriptor,
             and: .expect(pixelName: "m_mac_netp_wireguard_error_cannot_locate_tunnel_file_descriptor"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionWireguardErrorInvalidState(reason: "reason"),
             and: .expect(pixelName: "m_mac_netp_wireguard_error_invalid_state",
                          customFields: [
                            PixelKit.Parameters.reason: "reason"
                          ]),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionWireguardErrorFailedDNSResolution,
             and: .expect(pixelName: "m_mac_netp_wireguard_error_failed_dns_resolution"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionWireguardErrorCannotSetNetworkSettings(TestError.testError),
             and: .expect(pixelName: "m_mac_netp_wireguard_error_cannot_set_network_settings",
                                 error: TestError.testError,
                                 underlyingErrors: [TestError.underlyingError]),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionWireguardErrorCannotStartWireguardBackend(code: 1),
             and: .expect(pixelName: "m_mac_netp_wireguard_error_cannot_start_wireguard_backend",
                          customFields: [
                            PixelKit.Parameters.errorCode: "1"
                          ]),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionNoAuthTokenFoundError,
             and: .expect(pixelName: "m_mac_netp_no_auth_token_found_error"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionRekeyAttempt,
             and: .expect(pixelName: "m_mac_netp_rekey_attempt"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionRekeyCompleted,
             and: .expect(pixelName: "m_mac_netp_rekey_completed"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionRekeyFailure(TestError.testError),
             and: .expect(pixelName: "m_mac_netp_rekey_failure",
                          error: TestError.testError,
                          underlyingErrors: [TestError.underlyingError]),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionSystemExtensionActivationFailure,
             and: .expect(pixelName: "m_mac_netp_system_extension_activation_failure"),
             file: #filePath,
             line: #line)
        fire(NetworkProtectionPixelEvent.networkProtectionUnhandledError(function: "function", line: 1, error: TestError.testError),
             and: .expect(pixelName: "m_mac_netp_unhandled_error",
                          error: TestError.testError,
                          underlyingErrors: [TestError.underlyingError],
                          customFields: [
                            PixelKit.Parameters.function: "function",
                            PixelKit.Parameters.line: "1",
                          ]),
             file: #filePath,
             line: #line)
    }
}

#endif
