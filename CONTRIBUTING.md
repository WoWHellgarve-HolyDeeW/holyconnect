# Contributing

HolyConnect is intentionally small and focused. Contributions are welcome when they improve USB access, Windows compatibility, diagnostics, documentation, or real-world board support.

Changes that widen the project into a general Windows networking tool are usually out of scope.

## Before Opening An Issue

- Run HolyConnect as Administrator.
- Confirm the Pi is connected to the DATA port, not the PWR port.
- If the run failed, attach the diagnostics package or at least the log file.
- Include the Pi model, hotspot board, Pi-Star version, and Windows version.
- Mention if the PC has Hyper-V, WSL, Docker, or VPN software installed.

English and Portuguese reports are both fine.

## Diagnostics And Privacy

HolyConnect can export logs, adapter details, routes, NAT state, and device information to help troubleshoot first-run problems.

- Review the diagnostics package before posting it publicly.
- Remove anything you do not want to publish, such as computer names or local adapter names.
- If you prefer, attach only the log file first and add the full diagnostics package later.

## Good Bug Reports

A useful bug report usually includes:

- What you expected to happen.
- What actually happened.
- Whether the Pi became reachable over USB.
- Whether internet sharing worked or failed.
- Whether Windows needed a manual RNDIS driver install.
- The generated diagnostics package or log.

## Compatibility Reports

Success reports are useful too. If HolyConnect worked on your setup, report:

- Pi model.
- Hotspot board model.
- Pi-Star version.
- Windows version.
- Whether the PC had Hyper-V, WSL, Docker, or VPN software installed.
- Whether internet sharing worked automatically.

## Pull Requests

- Keep changes narrow and easy to review.
- Preserve the current safety rule: do not remove or rewrite unrelated Windows NAT rules.
- Avoid adding third-party dependencies unless there is a strong reason.
- Update both README files when user-facing behavior changes.
- Mention how you tested the change.

If you are changing driver detection, NAT handling, or diagnostics export, include a short note about the failure mode you are fixing.