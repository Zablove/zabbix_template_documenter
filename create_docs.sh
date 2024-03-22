#!/bin/bash

# Check args
if [ "$#" -ne 1 ]; then
    echo "Use: $0 <directory>"
    exit 1
fi

# Dir JSON files
json_dir="$1"

# Check if dir exists
if [ ! -d "$json_dir" ]; then
    echo "Error, directory $json_dir does not exist"
    exit 1
fi

# Make sure path ends with /
if [ "${json_dir: -1}" != "/" ]; then
    json_dir="${json_dir}/"
fi

# Itterate over JSON files in dir
for json_file in "$json_dir"*.json; do
    # Check if it's a file
    if [ -f "$json_file" ]; then
        echo "Parse template: $json_file"

  # Define readme filename
  #md_file=$(echo $json_file | sed 's/.json$/.md/g')
  filename=$(jq -r '.zabbix_export.templates[0].template' "$json_file" | sed 's/ /_/g' | sed 's/_-_/_/g')
  md_file=$(echo $json_dir$filename.md)

  # count items, macros, discovery rules and linked templates
  num_items=$(jq '.zabbix_export.templates[0].items | length' "$json_file")
  num_macros=$(jq '.zabbix_export.templates[0].macros | length' "$json_file")
  num_discovery_rules=$(jq '.zabbix_export.templates[0].discovery_rules | length' "$json_file")
  num_linked_templates=$(jq '.zabbix_export.templates[0].templates | length' "$json_file")


  # Extracting template name and description using jq
  template_name=$(jq -r '.zabbix_export.templates[0].name' "$json_file")
  template_description=$(jq -r '.zabbix_export.templates[0].description' "$json_file")

  # Writing extracted values to a text file
  ## Name:
  echo "# $template_name" > $md_file
  ## Description
  echo "## Description" >> $md_file
  echo "$template_description" >> $md_file

  ## Linkeded templates
  if [[ "$num_linked_templates" -ge 1 ]]; then
      echo "## Linked templates" >> $md_file
      echo "|Linked template|" >> $md_file
      echo "|---------------|" >> $md_file
      # Loop over all linked templates
      for ((i = 0; i < num_linked_templates; i++)); do
          linked_templ_name=$(jq -r ".zabbix_export.templates[0].templates[$i].name" "$json_file")
          # Write items to README
          echo "| $linked_templ_name |" >> $md_file
      done
  fi


  ## Macros
  if [[ "$num_macros" -ge 1 ]]; then
      echo "## Macros used" >> $md_file
      echo "|Name|Description|Default|" >> $md_file
      echo "|----|-----------|-------|" >> $md_file
      # Loop over all macros
      for ((i = 0; i < num_macros; i++)); do
          macro_name=$(jq -r ".zabbix_export.templates[0].macros[$i].macro" "$json_file")
          macro_value=$(jq -r ".zabbix_export.templates[0].macros[$i].value" "$json_file")
          macro_description=$(jq -r ".zabbix_export.templates[0].macros[$i].description" "$json_file" | sed 's/^null$//g')
          # Write items to README
          echo "| $macro_name | $macro_description | $macro_value " >> $md_file
      done
  fi


  ## Items
  if [[ "$num_items" -ge 1 ]]; then
      echo "## Items" >> $md_file
      echo "|Name|Description|Type|Key and additional info|" >> $md_file
      echo "|----|-----------|----|-----------------------|" >> $md_file
      # Loop over all items
      for ((i = 0; i < num_items; i++)); do
          item_name=$(jq -r ".zabbix_export.templates[0].items[$i].name" "$json_file")
          item_description=$(jq -r ".zabbix_export.templates[0].items[$i].description" "$json_file" | sed 's/^null$//g')
          #item_description=$(jq -r ".zabbix_export.templates[0].items[$i].description" "$json_file" | sed ':a;N;$!ba;s/\n/\\n/g')
          item_description=$(echo "$item_description" | tr '\n' ' ')
          item_type=$(jq -r ".zabbix_export.templates[0].items[$i].type" "$json_file")
          item_key=$(jq -r ".zabbix_export.templates[0].items[$i].key" "$json_file")
          # Write items to README
          echo "| $item_name | $item_description | $item_type | $item_key " >> $md_file
      done
  fi

  ## Add Triggers
  total_triggers=$(jq -r "[.zabbix_export.templates[0].items[]?.triggers | length] | add" "$json_file")
  if [[ "$total_triggers" -ge 1 ]]; then
      echo "## Triggers" >> $md_file
      echo "|Name|Description|Expression|Severity|Dependencies and additional info|" >> $md_file
      echo "|----|-----------|----------|--------|--------------------------------|" >> $md_file
      # Loop over all items to check if they had triggers
      for ((i = 0; i < num_items; i++)); do
          # Loop over all triggers
          num_triggers=$(jq ".zabbix_export.templates[0].items[$i].triggers | length" "$json_file")
          for ((j = 0; j < num_triggers; j++)); do
              trigger_name=$(jq -r ".zabbix_export.templates[0].items[$i].triggers[$j].name" "$json_file")
              trigger_description=$(jq -r ".zabbix_export.templates[0].items[$i].triggers[$j].description" "$json_file" | tr '\n' ' ')
              trigger_expression=$(jq -r ".zabbix_export.templates[0].items[$i].triggers[$j].expression" "$json_file")
              trigger_priority=$(jq -r ".zabbix_export.templates[0].items[$i].triggers[$j].priority" "$json_file")
              trigger_dependencies=$(jq -r ".zabbix_export.templates[0].items[$i].triggers[$j].dependencies" "$json_file")
                  # If variables set, extract them:
                  if [ "$trigger_dependencies" != "null" ]; then
                  trigger_dependencies_name=$(jq -r ".zabbix_export.templates[0].items[$i].triggers[$j].dependencies[0].name" "$json_file")
                  #trigger_dependencies_deps=$(jq -r ".zabbix_export.templates[0].items[$i].triggers[$j].dependencies[0].expression" "$json_file")
                  trigger_debs=$(echo "**Depends on**: $trigger_dependencies_name")
                  fi
              # Write triggers to README
              echo "| $trigger_name | $trigger_description | $trigger_expression | $trigger_priority | $trigger_debs |" >> $md_file
          done
      done
  fi

  ## Add Discovery Rules
  if [[ "$num_discovery_rules" -ge 1 ]]; then
  total_item_prototypes=$(jq -r "[.zabbix_export.templates[0].discovery_rules[].item_prototypes | length] | add" "$json_file")
    if [[ "$total_item_prototypes" -ge 1 ]]; then
      for ((i = 0; i < num_discovery_rules; i++)); do
      lld_rule_name=$(jq -r ".zabbix_export.templates[0].discovery_rules[$i].name" "$json_file")
      lld_rule_desc=$(jq -r ".zabbix_export.templates[0].discovery_rules[$i].description" "$json_file" | sed 's/^null$//g')
      lld_rule_type=$(jq -r ".zabbix_export.templates[0].discovery_rules[$i].type" "$json_file")
      lld_rule_key=$(jq -r ".zabbix_export.templates[0].discovery_rules[$i].key" "$json_file")
      echo "## LLD rule $lld_rule_name" >> $md_file
      echo "|Name|Description|Type|Key|" >> $md_file
      echo "|----|-----------|----|---|" >> $md_file
      echo "| $lld_rule_name | $lld_rule_desc | $lld_rule_type | $lld_rule_key " >> $md_file

      # Count and add LLD items
      lld_item_count=$(jq -r ".zabbix_export.templates[0].discovery_rules[$i].item_prototypes | length" "$json_file")
      if [[ "$lld_item_count" -ge 1 ]]; then
        echo "### Item prototypes for $lld_rule_name" >> $md_file
        echo "|Name|Description|Type|Key|" >> $md_file
        echo "|----|-----------|----|---|" >> $md_file
            for ((j = 0; j < lld_item_count; j++)); do
            lld_item_name=$(jq -r ".zabbix_export.templates[0].discovery_rules[$i].item_prototypes[$j].name" "$json_file")
            lld_item_desc=$(jq -r ".zabbix_export.templates[0].discovery_rules[$i].item_prototypes[$j].description" "$json_file" | sed 's/^null$//g' | tr '\n' ' ')
            lld_item_type=$(jq -r ".zabbix_export.templates[0].discovery_rules[$i].item_prototypes[$j].type" "$json_file")
            lld_item_key=$(jq -r ".zabbix_export.templates[0].discovery_rules[$i].item_prototypes[$j].key" "$json_file")
            echo "| $lld_item_name | $lld_item_desc | $lld_item_type | $lld_item_key " >> $md_file
            done
        total_trigger_prototypes=$(jq -r "[.zabbix_export.templates[0].discovery_rules[].item_prototypes[]?.trigger_prototypes | length] | add" "$json_file")
        num_trigger_prototype=$(jq -r "[.zabbix_export.templates[0].discovery_rules[$i].item_prototypes[].trigger_prototypes | length] | add" "$json_file")
        #echo "Checkpoint 1"
        #num_discovery_prototype=0
        if [[ "$num_trigger_prototype" -ge 1 ]]; then
        echo "### Trigger prototypes for $lld_rule_name" >> $md_file
        echo "|Name|Description|Espression|Severity|Dependencies|" >> $md_file
        echo "|----|-----------|----------|--------|------------|" >> $md_file
            for ((j = 0; j < lld_item_count; j++)); do
            lld_trigger_count=$(jq -r ".zabbix_export.templates[0].discovery_rules[$i].item_prototypes[$j].trigger_prototypes | length" "$json_file")
                for ((k = 0; k < lld_trigger_count; k++)); do
                lld_trigger_name=$(jq -r ".zabbix_export.templates[0].discovery_rules[$i].item_prototypes[$j].trigger_prototypes[$k].name" "$json_file")
                lld_trigger_desc=$(jq -r ".zabbix_export.templates[0].discovery_rules[$i].item_prototypes[$j].trigger_prototypes[$k].description" "$json_file" | sed 's/^null$//g'  | tr '\n' ' ')
                lld_trigger_expr=$(jq -r ".zabbix_export.templates[0].discovery_rules[$i].item_prototypes[$j].trigger_prototypes[$k].expression" "$json_file")
                lld_trigger_severity=$(jq -r ".zabbix_export.templates[0].discovery_rules[$i].item_prototypes[$j].trigger_prototypes[$k].priority" "$json_file")
                lld_trigger_dependencies=(jq -r ".zabbix_export.templates[0].discovery_rules[$i].item_prototypes[$j].trigger_prototypes[$k].dependencies[0].name" "$json_file")
                    if [ -n "$lld_trigger_dependencies" ]; then
                    lld_trigger_dependencies=$(jq -r ".zabbix_export.templates[0].discovery_rules[$i].item_prototypes[$j].trigger_prototypes[$k].dependencies[0].name" "$json_file")
                    lld_trigger_debs=$(echo "**Depends on**: $lld_trigger_dependencies" | sed 's/\*\*Depends on\*\*\: null//g')
                    else
                    lld_trigger_debs=" "
                    fi
                echo "| $lld_trigger_name | $lld_trigger_desc | $lld_trigger_expr | $lld_trigger_severity | $lld_trigger_debs " >> $md_file
                done
            done
        fi
      fi
      done
    fi
  fi

  # Check for host prototypes
  if [[ "$num_discovery_rules" -ge 1 ]]; then
  total_host_prototypes=$(jq -r "[.zabbix_export.templates[0].discovery_rules[].host_prototypes | length] | add" "$json_file")

    for ((i = 0; i < num_discovery_rules; i++)); do
    num_host_prototype=$(jq -r ".zabbix_export.templates[0].discovery_rules[$i].host_prototypes | length" "$json_file")
      if [[ "$num_host_prototype" -ge 1 ]]; then
      lld_rule_name=$(jq -r ".zabbix_export.templates[0].discovery_rules[$i].name" "$json_file")
      echo "### Host prototypes for $lld_rule_name" >> $md_file
      echo "|Hostname|Templates|" >> $md_file
      echo "|--------|---------|" >> $md_file

      for ((j = 0; j < num_host_prototype; j++)); do
      prototype_name=$(jq -r ".zabbix_export.templates[0].discovery_rules[$i].host_prototypes[$j].name" "$json_file")
      prototype_templates=$(jq -r ".zabbix_export.templates[0].discovery_rules[$i].host_prototypes[$j].templates[].name" "$json_file")
      echo "| $prototype_name | $prototype_templates " >> $md_file
      done
      fi
    done
  fi

  echo "Extracted values written to $md_file"
  echo "### Stats" >> $md_file
  echo "Macros: $num_macros" >> $md_file
  echo "Items: $num_items" >> $md_file
  echo "Triggers: $total_triggers" >> $md_file
  echo "LLD Rules: $num_discovery_rules" >> $md_file
  echo "Item prototypes: $total_item_prototypes" >> $md_file
  echo "Trigger prototypes: $total_trigger_prototypes" >> $md_file
  echo "Host prototypes: $total_host_prototypes" >> $md_file
  echo "Document created at $(date +'%d-%m-%Y')" >> $md_file
  echo "[Template Documebt Builder by Zablove](https://github.com/Zablove)" >> $md_file

fi
done