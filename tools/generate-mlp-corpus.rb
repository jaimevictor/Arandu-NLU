#!/usr/bin/env ruby
# frozen_string_literal: true

# PROJECT_AUTHORED_SYNTHETIC generator. Apache-2.0.

require "fileutils"
require "json"

ROOT = File.expand_path("..", __dir__)
OUTPUT_DIR = File.join(ROOT, "data", "mlp")
CATALOG_PATH = File.join(
  OUTPUT_DIR,
  "project-authored-synthetic-catalog-v1.json"
)
CORPUS_PATH = File.join(
  OUTPUT_DIR,
  "project-authored-synthetic-v1.jsonl"
)

def sorted(value)
  case value
  when Hash
    value.keys.sort.each_with_object({}) do |key, result|
      result[key] = sorted(value.fetch(key))
    end
  when Array
    value.map { |item| sorted(item) }
  else
    value
  end
end

def encoded(value)
  JSON.generate(sorted(value))
end

def operation(action, targets, percentage = nil)
  result = {
    "action" => action,
    "targets" => targets.sort,
  }
  result["percentage"] = percentage unless percentage.nil?
  result
end

def plan(*operations)
  {
    "operations" => operations,
    "status" => "plan",
    "version" => 1,
  }
end

def outcome(status)
  {
    "status" => status,
    "version" => 1,
  }
end

catalog = {
  "areas" => [
    {
      "area_id" => "area_cozinha",
      "names" => ["cozinha"],
    },
    {
      "area_id" => "area_quarto",
      "names" => ["quarto", "dormitório"],
    },
    {
      "area_id" => "area_sala",
      "names" => ["sala", "sala de estar"],
    },
  ],
  "entities" => [
    {
      "actions" => %w[get_state turn_off turn_on],
      "area_id" => "area_sala",
      "domain" => "light",
      "entity_id" => "light.abajur_sala",
      "names" => ["abajur", "abajur da sala"],
      "registry_id" => "reg_light_abajur_sala",
    },
    {
      "actions" => %w[get_state turn_off turn_on],
      "area_id" => "area_quarto",
      "domain" => "light",
      "entity_id" => "light.abajur_quarto",
      "names" => ["abajur", "abajur do quarto"],
      "registry_id" => "reg_light_abajur_quarto",
    },
    {
      "actions" => %w[get_state turn_off turn_on],
      "area_id" => "area_quarto",
      "domain" => "light",
      "entity_id" => "light.luz_quarto",
      "names" => ["luz do quarto", "luz principal do quarto"],
      "registry_id" => "reg_light_quarto",
    },
    {
      "actions" => %w[get_state turn_off turn_on],
      "area_id" => "area_sala",
      "domain" => "light",
      "entity_id" => "light.luz_sala",
      "names" => ["luz da sala", "luz principal da sala"],
      "registry_id" => "reg_light_sala",
    },
    {
      "actions" => %w[get_state turn_off turn_on],
      "area_id" => "area_cozinha",
      "domain" => "switch",
      "entity_id" => "switch.cafeteira",
      "names" => ["cafeteira", "interruptor da cafeteira"],
      "registry_id" => "reg_switch_cafeteira",
    },
    {
      "actions" => %w[
        get_state
        set_fan_percentage
        turn_off
        turn_on
      ],
      "area_id" => "area_quarto",
      "domain" => "fan",
      "entity_id" => "fan.ventilador_quarto",
      "names" => ["ventilador", "ventilador do quarto"],
      "registry_id" => "reg_fan_quarto",
    },
    {
      "actions" => %w[get_state],
      "area_id" => "area_sala",
      "domain" => "sensor",
      "entity_id" => "sensor.temperatura_sala",
      "names" => ["temperatura da sala", "sensor de temperatura da sala"],
      "registry_id" => "reg_sensor_temperatura_sala",
    },
    {
      "actions" => %w[get_state],
      "area_id" => "area_sala",
      "domain" => "binary_sensor",
      "entity_id" => "binary_sensor.janela_sala",
      "names" => ["janela da sala", "sensor da janela da sala"],
      "registry_id" => "reg_binary_sensor_janela_sala",
    },
  ],
  "version" => 1,
}

cases = [
  [
    "turn-on-light-area",
    "Acenda a luz da sala.",
    plan(operation("turn_on", ["reg_light_abajur_sala", "reg_light_sala"])),
  ],
  [
    "turn-off-light-area-chain-ellipsis",
    "Apague a luz da sala e do quarto.",
    plan(
      operation(
        "turn_off",
        %w[
          reg_light_abajur_quarto
          reg_light_abajur_sala
          reg_light_quarto
          reg_light_sala
        ]
      )
    ),
  ],
  [
    "turn-off-light-area-chain-plural",
    "Desligue as luzes da sala e do dormitório.",
    plan(
      operation(
        "turn_off",
        %w[
          reg_light_abajur_quarto
          reg_light_abajur_sala
          reg_light_quarto
          reg_light_sala
        ]
      )
    ),
  ],
  [
    "ordered-mixed-actions",
    "Apague a luz da sala e ligue a luz do quarto.",
    plan(
      operation("turn_off", ["reg_light_abajur_sala", "reg_light_sala"]),
      operation(
        "turn_on",
        ["reg_light_abajur_quarto", "reg_light_quarto"]
      )
    ),
  ],
  [
    "ordered-switch-and-fan",
    "Ligue a cafeteira e desligue o ventilador do quarto.",
    plan(
      operation("turn_on", ["reg_switch_cafeteira"]),
      operation("turn_off", ["reg_fan_quarto"])
    ),
  ],
  [
    "entity-chain",
    "Apague o abajur da sala e o abajur do quarto.",
    plan(
      operation(
        "turn_off",
        ["reg_light_abajur_quarto", "reg_light_abajur_sala"]
      )
    ),
  ],
  [
    "fan-percentage-50",
    "Coloque o ventilador do quarto em 50 por cento.",
    plan(operation("set_fan_percentage", ["reg_fan_quarto"], 50)),
  ],
  [
    "fan-percentage-symbol",
    "Ajuste o ventilador para 25%.",
    plan(operation("set_fan_percentage", ["reg_fan_quarto"], 25)),
  ],
  [
    "fan-percentage-zero",
    "Defina o ventilador do quarto para 0 por cento.",
    plan(operation("set_fan_percentage", ["reg_fan_quarto"], 0)),
  ],
  [
    "fan-percentage-in-chain",
    "Ligue a cafeteira e coloque o ventilador em 40 por cento.",
    plan(
      operation("turn_on", ["reg_switch_cafeteira"]),
      operation("set_fan_percentage", ["reg_fan_quarto"], 40)
    ),
  ],
  [
    "read-light-state",
    "Qual é o estado da luz principal da sala?",
    plan(operation("get_state", ["reg_light_sala"])),
  ],
  [
    "read-temperature",
    "Qual é a temperatura da sala?",
    plan(operation("get_state", ["reg_sensor_temperatura_sala"])),
  ],
  [
    "read-temperature-alternate",
    "Quanto está o sensor de temperatura da sala?",
    plan(operation("get_state", ["reg_sensor_temperatura_sala"])),
  ],
  [
    "read-binary-sensor",
    "Como está a janela da sala?",
    plan(operation("get_state", ["reg_binary_sensor_janela_sala"])),
  ],
  [
    "case-and-diacritic-normalization",
    "DESLIGUE AS LUZES DO DORMITÓRIO!",
    plan(
      operation(
        "turn_off",
        ["reg_light_abajur_quarto", "reg_light_quarto"]
      )
    ),
  ],
  [
    "ambiguous-entity",
    "Acenda o abajur.",
    outcome("ambiguous"),
  ],
  [
    "invalid-percentage-high",
    "Coloque o ventilador em 101 por cento.",
    outcome("no_match"),
  ],
  [
    "invalid-percentage-negative",
    "Coloque o ventilador em menos dez por cento.",
    outcome("no_match"),
  ],
  [
    "contradictory-target-chain",
    "Apague a luz da sala e ligue a luz da sala.",
    outcome("no_match"),
  ],
  [
    "query-effect-chain",
    "Qual é o estado da cafeteira e desligue a cafeteira.",
    outcome("no_match"),
  ],
  [
    "unsupported-toggle",
    "Alterne a luz da sala.",
    outcome("no_match"),
  ],
  [
    "unsupported-climate",
    "Ajuste o ar condicionado para vinte graus.",
    outcome("no_match"),
  ],
  [
    "unknown-area",
    "Apague a luz da varanda.",
    outcome("no_match"),
  ],
  [
    "empty",
    "",
    outcome("invalid_request"),
  ],
]

corpus = cases.map do |identifier, text, expected|
  encoded(
    {
      "catalog" => "project-authored-synthetic-catalog-v1",
      "expected" => expected,
      "id" => identifier,
      "license" => "Apache-2.0",
      "spec_version" => 1,
      "text" => text,
    }
  )
end.join("\n") + "\n"

catalog_bytes = encoded(catalog) + "\n"

if ARGV == ["--check"]
  unless File.binread(CATALOG_PATH) == catalog_bytes.b
    warn "generated MLP catalog differs"
    exit 1
  end
  unless File.binread(CORPUS_PATH) == corpus.b
    warn "generated MLP corpus differs"
    exit 1
  end
  puts "MLP corpus is reproducible"
  exit 0
end

unless ARGV.empty?
  warn "usage: tools/generate-mlp-corpus [--check]"
  exit 2
end

FileUtils.mkdir_p(OUTPUT_DIR)
File.binwrite(CATALOG_PATH, catalog_bytes)
File.binwrite(CORPUS_PATH, corpus)
puts "wrote #{CATALOG_PATH}"
puts "wrote #{CORPUS_PATH}"
