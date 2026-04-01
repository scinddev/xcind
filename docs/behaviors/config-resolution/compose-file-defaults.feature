# This feature verifies behaviors from:
# See: ../../specs/configuration-schemas.md

Feature: Compose File Defaults
  As a developer using xcind
  I want sensible defaults when .xcind.sh does not specify compose files
  So that xcind works out of the box with standard Docker Compose conventions

  Scenario: Default compose file candidates
    Given an application with an empty .xcind.sh configuration
    When xcind loads the configuration
    Then XCIND_COMPOSE_FILES contains 4 entries:
      | compose.yaml         |
      | compose.yml          |
      | docker-compose.yaml  |
      | docker-compose.yml   |

  Scenario: Default environment file
    Given an application with an empty .xcind.sh configuration
    When xcind loads the configuration
    Then XCIND_COMPOSE_ENV_FILES contains 1 entry:
      | .env |

  Scenario: Default app env files is empty
    Given an application with an empty .xcind.sh configuration
    When xcind loads the configuration
    Then XCIND_APP_ENV_FILES is empty

  Scenario: Default compose directory is empty
    Given an application with an empty .xcind.sh configuration
    When xcind loads the configuration
    Then XCIND_COMPOSE_DIR is empty

  Scenario: Custom .xcind.sh overrides defaults
    Given an application with a .xcind.sh that sets XCIND_COMPOSE_FILES=("compose.yaml")
    When xcind loads the configuration
    Then XCIND_COMPOSE_FILES contains 1 entry:
      | compose.yaml |

  Scenario: Backwards-compatible XCIND_ENV_FILES migration
    Given an application with a .xcind.sh that sets XCIND_ENV_FILES=(".env.local")
    When xcind loads the configuration
    Then XCIND_COMPOSE_ENV_FILES contains 1 entry:
      | .env.local |
    And a deprecation warning is emitted to stderr
