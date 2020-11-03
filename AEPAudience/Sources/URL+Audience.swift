/*
 Copyright 2020 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0
 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import Foundation
import AEPIdentity
import AEPServices

extension URL {

    private static let LOG_TAG = "URL+Audience"

    /// Creates a new Audience Manager hit URL
    /// - Parameters:
    ///   - state: the Audience State containing Audience-related variables.
    static func buildAudienceHitURL(state: AudienceState?) -> URL? {
        let aamServer = state?.getAamServer() ?? ""

        // bail if the aam server is empty
        if aamServer.isEmpty {
            Log.error(label: LOG_TAG, "Building Audience hit URL failed - (Audience Server not found in configuration shared state), returning nil.")
            return nil
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = aamServer
        components.path = "/event"

        var queryItems: [URLQueryItem] = []

        // Attach the customer data sent by the SignalWithData API
        let customerEventData = state?.getCustomerEventData() ?? [:]
        for (key, value) in customerEventData {
            if key.isEmpty || value.isEmpty {
                continue
            }
            let keyWithPrefix = AudienceConstants.URLKeys.CUSTOMER_DATA_PREFIX + key
            queryItems +=  [URLQueryItem(name: keyWithPrefix, value: value)]
        }

        // Attach mid, blob, locationHint, visitorIdList from Identity shared state
        if let marketingCloudId = state?.getEcid() as String?, !marketingCloudId.isEmpty {
            queryItems += [URLQueryItem(name: AudienceConstants.DestinationKeys.VISITOR_ID_MID_KEY, value: marketingCloudId)]
        }

        if let blob = state?.getBlob() as String?, !blob.isEmpty {
            queryItems += [URLQueryItem(name: AudienceConstants.DestinationKeys.VISITOR_ID_BLOB_KEY, value: blob)]
        }

        if let locationHint = state?.getLocationHint() as String?, !locationHint.isEmpty {
            queryItems += [URLQueryItem(name: AudienceConstants.DestinationKeys.VISITOR_ID_LOCATION_HINT_KEY, value: locationHint)]
        }

        // Attach custom visitorId list synced on Identity extension
        if let customerVisitorIdList = state?.getVisitorIds() as [CustomIdentity]?, !customerVisitorIdList.isEmpty {
            for id in customerVisitorIdList {
                let idType = id.type!
                let idValue = id.identifier ?? ""
                let idAuthState = id.authenticationState.rawValue

                var visitorIdString = ""
                visitorIdString.append(idType)
                visitorIdString.append(AudienceConstants.DestinationKeys.VISITOR_ID_CID_DELIMITER)
                if !idValue.isEmpty {
                    visitorIdString.append(idValue)
                }

                visitorIdString.append(AudienceConstants.DestinationKeys.VISITOR_ID_CID_DELIMITER)
                visitorIdString.append(String(idAuthState))

                queryItems += [URLQueryItem(name: AudienceConstants.DestinationKeys.VISITOR_ID_PARAMETER_KEY_CUSTOMER, value: visitorIdString)]
            }

        }

        // Attach experience cloud org id from configruration shared state
        if let experienceCloudOrgId = state?.getOrgId() as String?, !experienceCloudOrgId.isEmpty {
            queryItems += [URLQueryItem(name: AudienceConstants.DestinationKeys.EXPERIENCE_CLOUD_ORG_ID, value: experienceCloudOrgId)]
        }

        // Attach uuid
        if let uuid = state?.getUuid() as String?, !uuid.isEmpty  {
            queryItems += [URLQueryItem(name: AudienceConstants.DestinationKeys.USER_ID_KEY, value: uuid)]
        }

        // Attach platform suffix
        queryItems += [URLQueryItem(name: AudienceConstants.URLKeys.PLATFORM_KEY, value: "ios")]

        // Attach URL suffix        
        queryItems += [URLQueryItem(name: "d_dst", value: "1")]
        queryItems += [URLQueryItem(name: "d_rtbd", value: "json")]

        components.queryItems = queryItems

        guard let url = components.url else {
            Log.error(label: LOG_TAG, "Building Audience hit URL failed, returning nil.")
            return nil
        }
        return url
    }

    /// Builds the `URL` responsible for sending an opt-out hit
    /// - Parameters:
    ///   - aamServer: the audience manager server
    ///   - uuid: the audience manager unique user id
    /// - Returns: A network request configured to send the opt-out request, nil if failed
    static func buildOptOutURL(aamServer: String, uuid: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = aamServer
        components.path = AudienceConstants.URLKeys.OPT_OUT_URL_PATH
        components.queryItems = [
            URLQueryItem(name: AudienceConstants.URLKeys.OPT_OUT_URL_AAM_UUID, value: uuid)
        ]

        guard let url = components.url else {
            Log.error(label: LOG_TAG, "Building Audience Manager opt-out hit URL failed, returning nil.")
            return nil
        }
        return url
    }
}
