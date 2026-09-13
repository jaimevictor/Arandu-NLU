# Local PT-BR NLU

Install and start this app, then install the `local_nlu` companion integration
and enter the app's internal HTTP origin. No app options are required.

The app interprets request-local text and catalog data in memory and returns a
typed plan. It cannot call Home Assistant. The companion integration performs
all live checks and is the only component that can execute services.
