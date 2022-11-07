---
title: "Finding an unreleased Windows feature - Tenant Restrictions v2 (TRv2)"
date: 2022-10-27
draft: false
tags: ["azure", "rev"]
---
The Windows 11 ADMXs released a while back, and there's an interesting new category - "Tenant Restrictions". It shares a name with an [Azure AD feature](https://learn.microsoft.com/en-us/azure/active-directory/manage-apps/tenant-restrictions) for restricting endpoints to specific tenants, but that typically requires a beefy TLS decryption appliance and expensive supporting infrastructure (VPNs etc). The ADMX category only has one policy, "Cloud Policy Details" (ID `trv2_payload`), but fortunately it has a detailed description:

>This setting enables and configures the device-based tenant restrictions feature for Azure Active Directory.
>
>When you enable this setting, compliant applications will be prevented from accessing disallowed tenants, according to a policy set in your Azure AD tenant.
>
>Note: Creation of a policy in your home tenant is required, and additional security measures for managed devices are recommended for best protection. Refer to Azure AD Tenant Restrictions for more details. https://go.microsoft.com/fwlink/?linkid=2148762
>
>Before enabling firewall protection, ensure that a Windows Defender Application Control (WDAC) policy that correctly tags applications has been applied to the target devices. Enabling firewall protection without a corresponding WDAC policy will prevent all applications from reaching Microsoft endpoints. This firewall setting is not supported on all versions of Windows - see the following link for more information. For details about setting up WDAC with tenant restrictions, see https://go.microsoft.com/fwlink/?linkid=2155230

Sounds like an endpoint-based version of the existing feature? Sure enough, the ADMX's description reads "Prototype policies for Tenant Restrictions v2". And both those links currently redirect to unrelated docs pages; a common Microsoft tactic for unreleased features. At least the policy has some options:

>Cloud ID (optional): sounds like an option for sovereign clouds (eg US GCC), defaulting to the standard commercial cloud (microsoftonline.com)
>
>Azure AD Directory ID: [tenant ID](https://www.whatismytenantid.com/)
>
>Policy GUID: short text
>
>Enable firewall protection of Microsoft endpoints: boolean

Plus three optional large text fields: Hostnames, Subdomain Supported Hostnames, and IP Ranges. Setting the tenant ID and a dummy policy ID results in an AADSTS1000108 error when authenticating:

> The policy ID \<GUID> provided in the sec-Restrict-Tenant-Access-Policy header did not match a policy ID in tenant \<tenant display name>. Please contact your administrator for assistance.

DevTools shows TRv2 is adding a `Sec-Restrict-Tenant-Access-Policy: tenantId:policyId` HTTP header on requests to certain domains, similar to how `Restrict-Access-To-Tenants` was used with TRv1. There's also a new `xms_trpid` ID token claim issued on tenant-restricted sessions (thanks [jwt.ms](https://jwt.ms)), containing the policyId.

Time for some OSINT (aka google-fu). There's a [StackOverflow post](https://stackoverflow.com/a/62704562) implying Microsoft have used TRv2 internally since mid-2020, and a [GitHub issue](https://github.com/MicrosoftDocs/WDAC-Toolkit/issues/71) for "TRv2 interaction in the Wizard" on a popular WDAC tool, but no technical details. I finally stumbled upon a [blog post from Vasil Michev](https://www.michev.info/Blog/Post/3681/cross-tenant-access-policy-xtap-and-the-graph-api) on [cross-tenant access policies](https://learn.microsoft.com/en-us/graph/api/crosstenantaccesspolicyconfigurationdefault-get?view=graph-rest-beta&tabs=http), which referenced a `tenantRestrictions` property. [Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer/preview) was ideal for testing this.

```http
GET https://graph.microsoft.com/beta/policies/crossTenantAccessPolicy/default
```
```json
{
    "id": "<GUID>",
    "tenantRestrictions": {
        "devices": null,
        "usersAndGroups": {
            "accessType": "blocked",
            "targets": [
                {
                    "target": "AllUsers",
                    "targetType": "user"
                }
            ]
        },
        "applications": {
            "accessType": "blocked",
            "targets": [
                {
                    "target": "AllApplications",
                    "targetType": "application"
                }
            ]
        }
    }
}
```

Setting the GPO policy ID to the default cross-tenant policy GUID was successful (no more AADSTS1000108)! But custom cross-tenant policies for external tenants were rejected. The default policy is also used for tenant-wide settings like cross-cloud access, so TRv2 config might be tenant-wide too.

That `devices` property also looked interesting. After even more OSINT, it leaked in a recent [Graph Java SDK release](https://github.com/microsoftgraph/msgraph-beta-sdk-java/blob/1e544292ef39faa059dbecca60dea7003722cda7/src/main/java/com/microsoft/graph/models/DevicesFilter.java). The expected schema is:

```json
{
	"devices": {
		"mode": "allowed",
		"rule": "device filter"
	}
}
```

The rule supports standard Azure AD [device filters](https://learn.microsoft.com/en-us/azure/active-directory/conditional-access/concept-condition-filters-for-devices#filter-for-devices-graph-api), which could be particularly useful for PAW implementations.

That's about it for implementing this feature. When it releases, it will allow security-conscious organisations to take another step forward on their cloud journeys, removing one last dependency on expensive on-premises hardware.

In part 2, we'll experiment with Windows binaries to find out how this all works, and hopefully shed some light on the extra WDAC/firewall option.
