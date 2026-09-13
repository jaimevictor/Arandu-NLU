# Installation

## 1. Install the Home Assistant app

Copy the repository's `addon` directory to a local Home Assistant app/add-on
folder, for example `/addons/local_ptbr_nlu`, refresh the app store, then build,
install, and start **Local PT-BR NLU**.

The app exposes TCP 11555 only on Home Assistant's internal app network. It
needs no options, Home Assistant token, host network, ingress, or persistent
storage.

## 2. Install the companion integration

Copy `custom_components/local_nlu` into the Home Assistant configuration
directory as:

```text
config/custom_components/local_nlu
```

Restart Home Assistant, open **Settings → Devices & services → Add
integration**, and choose **Local NLU**.

The default app origin is:

```text
http://local-ptbr-nlu:11555
```

If the local app store assigned another internal hostname, enter that origin
instead. Public hosts, credentials, HTTPS URLs, paths, and redirects are
rejected.

## 3. Select the agent

Select **Local NLU** as the conversation agent for the desired Assist pipeline.
Expose only the entities that should be available to conversation agents.

## Supported examples

```text
Acenda a luz da sala.
Apague a luz da sala e do quarto.
Apague a luz da sala e ligue a luz do quarto.
Ligue a cafeteira e desligue o ventilador do quarto.
Coloque o ventilador do quarto em 50 por cento.
Qual é a temperatura da sala?
```

Names and areas must exactly match Home Assistant names or aliases after
case/diacritic normalization.

## Operational limits

- At most four ordered operations and four target clauses per operation.
- Fan speed is an integer from 0 through 100 percent.
- Query operations are standalone.
- The complete plan is preflighted before its first effect.
- Home Assistant service calls are not transactional. If Home Assistant fails
  unexpectedly during a later call, effects already completed are not rolled
  back.
- No utterance, catalog, credential, or execution history is persisted by the
  app.
