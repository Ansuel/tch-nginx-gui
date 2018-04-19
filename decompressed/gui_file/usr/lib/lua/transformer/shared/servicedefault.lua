-- This config file is provided for service modification or addition or deletion via TR-069 / GUI
-- The key is service type, content is table for providing default activities

-- Append table
-- This table is defined for the services when a new profile is added,
-- if the service type section is existing, the new profile is added in the current service section
-- if the service type is not existing, a new service section is created
-- Hence, the service provisioning in the table can be configured per gateway
local append_cfg = {
    HOLD = {
        provisioned = "1",
        activated = "1",
        servicetype = "profile"
    },
}

-- Add table
-- This table is defined for the services when a new profile is added,
-- whether the service type is existing or not, a new service section configuration is created.
-- Hence, the service provisioning in the table can be configured per profile/device
local add_cfg = {
    ACR = {
        provisioned = "1",
        activated = "0",
        servicetype = "profile"
    },
    CLIP = {
        provisioned = "1",
        activated = "1",
        servicetype = "profile"
    },
    CFBS = {
        provisioned = "1",
        activated = "0",
        servicetype = "profile"
    },
    CFNR = {
        provisioned = "1",
        activated = "0",
        timeout = "60",
        servicetype = "profile"
    },
    CFU = {
        provisioned = "1",
        activated = "0",
        servicetype = "profile"
    },
    CLIR = {
        provisioned = "0",
        activated = "0",
        servicetype = "profile"
    },
    CALL_RETURN = {
        provisioned = "1",
        activated = "0",
        servicetype = "profile"
    },
    MWI = {
        provisioned = "0",
        activated = "0",
        servicetype = "profile"
    },
}

-- This talbe is all the default configuration for services
-- append  - is key for append table
-- add     - is key for add table
local services_default_cfg = {
    append = append_cfg,
    add = add_cfg,
    named_service_section = false
}

-- Default configuration for a dial_plan_entry when added via TR-69 is defined here

local dial_plan_entry_table = {
    enabled = "1",
    allow = "1",
    include_eon = "0",
    priority = "low",
    apply_forced_profile = "0",
    min_length ="1",
    max_length ="30",
    pattern ="^ "
}

local profile_default = {
    services = services_default_cfg,
    dial_plan_entry_table = dial_plan_entry_table,
}
return profile_default

