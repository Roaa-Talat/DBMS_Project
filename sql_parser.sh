#!/bin/bash

# SQL Parser for Bash DBMS
# Supports: CREATE DATABASE, USE, CREATE TABLE, INSERT, SELECT, UPDATE, DELETE, DROP TABLE

# Global variable to store current database for SQL mode
SQL_CURRENT_DB=""

sql_parser() {
    echo "====================================="
    echo "           SQL Mode"
    echo "====================================="
    echo "Enter SQL commands (type 'exit' to quit, 'help' for help)"
    echo "Current database: ${SQL_CURRENT_DB:-none}"
    echo "====================================="
    
    while true; do
        if [ -z "$SQL_CURRENT_DB" ]; then
            read -p "SQL> " sql_command
        else
            read -p "$SQL_CURRENT_DB SQL> " sql_command
        fi
        
        if [[ "$sql_command" =~ ^[Ee][Xx][Ii][Tt] ]]; then
            echo "Exiting SQL mode..."
            return
        fi
        
        if [[ "$sql_command" =~ ^[Hh][Ee][Ll][Pp] ]]; then
            show_sql_help
            continue
        fi
        
        if [ -n "$sql_command" ]; then
            parse_sql_command "$sql_command"
        fi
    done
}

show_sql_help() {
    echo "====================================="
    echo "           SQL Help"
    echo "====================================="
    echo "Supported commands:"
    echo "  CREATE DATABASE database_name;            - Create new database"
    echo "  USE database_name;                        - Select database"
    echo "  CREATE TABLE table_name (...);            - Create table"
    echo "  INSERT INTO table_name VALUES (...);      - Insert record"
    echo "  SELECT * FROM table_name;                 - Select all"
    echo "  SELECT col1, col2 FROM table_name;        - Select columns"
    echo "  SELECT * FROM table_name WHERE col=val;   - Select with condition"
    echo "  UPDATE table_name SET col=val WHERE cond; - Update records"
    echo "  DELETE FROM table_name WHERE cond;        - Delete records"
    echo "  DROP TABLE table_name;                    - Drop table"
    echo "====================================="
}

parse_sql_command() {
    local sql_cmd="$1"
    
    sql_cmd=$(echo "$sql_cmd" | sed 's/;$//')
    
    local sql_upper=$(echo "$sql_cmd" | tr '[:lower:]' '[:upper:]')
    
    if [[ "$sql_upper" =~ ^CREATE[[:space:]]+DATABASE ]]; then
        parse_create_database "$sql_cmd"
    elif [[ "$sql_upper" =~ ^USE[[:space:]] ]]; then
        parse_use_database "$sql_cmd"
    elif [[ "$sql_upper" =~ ^CREATE[[:space:]]+TABLE ]]; then
        parse_create_table "$sql_cmd"
    elif [[ "$sql_upper" =~ ^INSERT[[:space:]]+INTO ]]; then
        parse_insert_into "$sql_cmd"
    elif [[ "$sql_upper" =~ ^SELECT ]]; then
        parse_select "$sql_cmd"
    elif [[ "$sql_upper" =~ ^UPDATE ]]; then
        parse_update "$sql_cmd"
    elif [[ "$sql_upper" =~ ^DELETE[[:space:]]+FROM ]]; then
        parse_delete "$sql_cmd"
    elif [[ "$sql_upper" =~ ^DROP[[:space:]]+TABLE ]]; then
        parse_drop_table "$sql_cmd"
    elif [[ "$sql_upper" =~ ^DROP[[:space:]]+DATABASE ]]; then
        parse_drop_database "$sql_cmd"
    else
        echo "Error: Unsupported SQL command or syntax error"
        echo "Type 'help' for list of supported commands"
    fi
}

parse_create_database() {
    local sql_cmd="$1"
    
    if [[ "$sql_cmd" =~ ^[Cc][Rr][Ee][Aa][Tt][Ee][[:space:]]+[Dd][Aa][Tt][Aa][Bb][Aa][Ss][Ee][[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\;?$ ]]; then
        local db_name="${BASH_REMATCH[1]}"
        
        if [[ ! "$db_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            echo "Error: Database name must start with a letter or underscore and contain only alphanumeric characters."
            return
        fi
        
        if [ -d "$DB_DIR/$db_name" ]; then
            echo "Error: Database '$db_name' already exists!"
        else
            mkdir -p "$DB_DIR/$db_name"
            echo "Database '$db_name' created successfully!"
        fi
    else
        echo "Error: Invalid CREATE DATABASE syntax"
        echo "Usage: CREATE DATABASE database_name;"
    fi
}

parse_use_database() {
    local sql_cmd="$1"
    
    if [[ "$sql_cmd" =~ ^[Uu][Ss][Ee][[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\;?$ ]]; then
        local db_name="${BASH_REMATCH[1]}"
        
        if [ -d "$DB_DIR/$db_name" ]; then
            SQL_CURRENT_DB="$db_name"
            echo "Database changed to '$db_name'"
        else
            echo "Error: Database '$db_name' does not exist!"
        fi
    else
        echo "Error: Invalid USE command syntax"
        echo "Usage: USE database_name;"
    fi
}

parse_create_table() {
    local sql_cmd="$1"
    
    if [ -z "$SQL_CURRENT_DB" ]; then
        echo "Error: No database selected. Use 'USE database_name;' first."
        return
    fi
    
    if [[ "$sql_cmd" =~ ^[Cc][Rr][Ee][Aa][Tt][Ee][[:space:]]+[Tt][Aa][Bb][Ll][Ee][[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\((.*)\)$ ]]; then
        local table_name="${BASH_REMATCH[1]}"
        local column_defs="${BASH_REMATCH[2]}"
        
        parse_column_definitions "$SQL_CURRENT_DB" "$table_name" "$column_defs"
    else
        echo "Error: Invalid CREATE TABLE syntax"
        echo "Usage: CREATE TABLE table_name (col1 TYPE, col2 TYPE PRIMARY KEY, ...);"
    fi
}

parse_column_definitions() {
    local db_name="$1"
    local table_name="$2"
    local column_defs="$3"
    
    column_defs=$(echo "$column_defs" | sed 's/[[:space:]]*,[[:space:]]*/,/g')
    IFS=',' read -ra col_array <<< "$column_defs"
    
    local col_count=${#col_array[@]}
    declare -a col_names
    declare -a col_types
    declare -a is_primary
    
    local primary_key_set=0
    local primary_key_col=""
    
    for ((i=0; i<col_count; i++)); do
        local col_def=$(echo "${col_array[i]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        if [[ "$col_def" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]+([Ii][Nn][Tt]|[Ss][Tt][Rr][Ii][Nn][Gg])[[:space:]]*[Pp][Rr][Ii][Mm][Aa][Rr][Yy][[:space:]]*[Kk][Ee][Yy]$ ]]; then
            col_names[$i]="${BASH_REMATCH[1]}"
            col_types[$i]=$(echo "${BASH_REMATCH[2]}" | tr '[:upper:]' '[:lower:]')
            is_primary[$i]=1
            primary_key_set=1
            
        elif [[ "$col_def" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]+([Ii][Nn][Tt]|[Ss][Tt][Rr][Ii][Nn][Gg])$ ]]; then
            col_names[$i]="${BASH_REMATCH[1]}"
            col_types[$i]=$(echo "${BASH_REMATCH[2]}" | tr '[:upper:]' '[:lower:]')
            is_primary[$i]=0
            
        else
            echo "Error: Invalid column definition: '$col_def'"
            echo "Format: column_name TYPE [PRIMARY KEY]"
            return
        fi
    done
    
    for ((i=0; i<col_count; i++)); do
        for ((j=i+1; j<col_count; j++)); do
            if [ "${col_names[$i]}" == "${col_names[$j]}" ]; then
                echo "Error: Duplicate column name '${col_names[$i]}'"
                return
            fi
        done
    done
    
    create_table_from_sql "$db_name" "$table_name" "$col_count" "${col_names[@]}" "${col_types[@]}" "${is_primary[@]}"
}

create_table_from_sql() {
    local db_name="$1"
    local table_name="$2"
    local col_count="$3"
    shift 3
    
    declare -a col_names
    declare -a col_types
    declare -a is_primary
    
    for ((i=0; i<col_count; i++)); do
        col_names[$i]="$1"
        shift
    done
    
    for ((i=0; i<col_count; i++)); do
        col_types[$i]="$1"
        shift
    done
    
    for ((i=0; i<col_count; i++)); do
        is_primary[$i]="$1"
        shift
    done
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    if [ -f "$meta_file" ]; then
        echo "Error: Table '$table_name' already exists!"
        return
    fi
    
    echo "col_count:$col_count" > "$meta_file"
    for ((i=0; i<col_count; i++)); do
        echo "col$((i+1))_name:${col_names[$i]}" >> "$meta_file"
        echo "col$((i+1))_type:${col_types[$i]}" >> "$meta_file"
        echo "col$((i+1))_primary:${is_primary[$i]}" >> "$meta_file"
    done
    
    touch "$data_file"
    echo "Table '$table_name' created successfully!"
}

parse_insert_into() {
    local sql_cmd="$1"
    
    if [ -z "$SQL_CURRENT_DB" ]; then
        echo "Error: No database selected. Use 'USE database_name;' first."
        return
    fi
    
    if [[ "$sql_cmd" =~ ^[Ii][Nn][Ss][Ee][Rr][Tt][[:space:]]+[Ii][Nn][Tt][Oo][[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]+[Vv][Aa][Ll][Uu][Ee][Ss][[:space:]]*\((.*)\)$ ]]; then
        local table_name="${BASH_REMATCH[1]}"
        local values_str="${BASH_REMATCH[2]}"
        
        IFS=',' read -ra values_array <<< "$values_str"
        
        for i in "${!values_array[@]}"; do
            values_array[$i]=$(echo "${values_array[$i]}" | sed -e "s/^[[:space:]]*//" -e "s/[[:space:]]*$//" -e "s/^'//" -e "s/'$//")
        done
        
        insert_into_table_sql "$SQL_CURRENT_DB" "$table_name" "${values_array[@]}"
        
    else
        echo "Error: Invalid INSERT INTO syntax"
        echo "Usage: INSERT INTO table_name VALUES (value1, 'value2', ...);"
    fi
}

insert_into_table_sql() {
    local db_name="$1"
    local table_name="$2"
    shift 2
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    if [ ! -f "$meta_file" ]; then
        echo "Error: Table '$table_name' does not exist!"
        return
    fi
    
    col_count=$(grep "^col_count:" "$meta_file" | cut -d: -f2)
    
    if [ $# -ne $col_count ]; then
        echo "Error: Expected $col_count values, got $#"
        return
    fi
    
    declare -a values=("$@")
    
    for ((i=1; i<=col_count; i++)); do
        col_type=$(grep "^col${i}_type:" "$meta_file" | cut -d: -f2)
        is_primary=$(grep "^col${i}_primary:" "$meta_file" | cut -d: -f2)
        value="${values[$((i-1))]}"
        
        if [ "$is_primary" -eq 1 ]; then
            if [ -z "$value" ]; then
                echo "Error: Primary key cannot be empty!"
                return
            fi
            
            if grep -q "^$value|" "$data_file" 2>/dev/null; then
                echo "Error: Primary key '$value' already exists!"
                return
            fi
        fi
        
        if [ "$col_type" == "int" ] && [[ ! "$value" =~ ^-?[0-9]+$ ]]; then
            echo "Error: Column $i must be integer, got '$value'"
            return
        fi
    done
    
    row_data=$(IFS='|'; echo "${values[*]}")
    echo "$row_data" >> "$data_file"
    echo "1 row inserted successfully!"
}

parse_select() {
    local sql_cmd="$1"
    
    if [ -z "$SQL_CURRENT_DB" ]; then
        echo "Error: No database selected. Use 'USE database_name;' first."
        return
    fi
    
    if [[ "$sql_cmd" =~ ^[Ss][Ee][Ll][Ee][Cc][Tt][[:space:]]+\*[[:space:]]+[Ff][Rr][Oo][Mm][[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)([[:space:]]+[Ww][Hh][Ee][Rr][Ee][[:space:]]+(.*))?$ ]]; then
        local table_name="${BASH_REMATCH[1]}"
        local where_clause="${BASH_REMATCH[3]}"
        
        if [ -n "$where_clause" ]; then
            parse_where_clause "$SQL_CURRENT_DB" "$table_name" "$where_clause" "all"
        else
            select_all "$SQL_CURRENT_DB" "$table_name"
        fi
        
    elif [[ "$sql_cmd" =~ ^[Ss][Ee][Ll][Ee][Cc][Tt][[:space:]]+([a-zA-Z_][a-zA-Z0-9_ ,]+)[[:space:]]+[Ff][Rr][Oo][Mm][[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)([[:space:]]+[Ww][Hh][Ee][Rr][Ee][[:space:]]+(.*))?$ ]]; then
        local columns="${BASH_REMATCH[1]}"
        local table_name="${BASH_REMATCH[2]}"
        local where_clause="${BASH_REMATCH[4]}"
        
        columns=$(echo "$columns" | sed 's/[[:space:]]*,[[:space:]]*/,/g')
        IFS=',' read -ra col_array <<< "$columns"
        
        for i in "${!col_array[@]}"; do
            col_array[$i]=$(echo "${col_array[$i]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        done
        
        if [ -n "$where_clause" ]; then
            parse_where_clause "$SQL_CURRENT_DB" "$table_name" "$where_clause" "${col_array[*]}"
        else
            select_columns_sql "$SQL_CURRENT_DB" "$table_name" "${col_array[@]}"
        fi
        
    else
        echo "Error: Invalid SELECT syntax"
        echo "Usage: SELECT * FROM table_name [WHERE condition];"
        echo "       SELECT col1, col2 FROM table_name [WHERE condition];"
    fi
}

get_column_index() {
    local db_name="$1"
    local table_name="$2"
    local col_name="$3"
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    
    if [ ! -f "$meta_file" ]; then
        return
    fi
    
    for i in {1..100}; do
        col_line=$(grep "^col${i}_name:" "$meta_file" 2>/dev/null)
        if [ -n "$col_line" ]; then
            found_name=$(echo "$col_line" | cut -d: -f2)
            if [ "$found_name" == "$col_name" ]; then
                echo "$i"
                return
            fi
        else
            break
        fi
    done
    echo ""
}

select_columns_sql() {
    local db_name="$1"
    local table_name="$2"
    shift 2
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    if [ ! -f "$meta_file" ]; then
        echo "Error: Table '$table_name' does not exist!"
        return
    fi
    
    declare -a col_indices
    declare -a col_names_display
    
    for col_name in "$@"; do
        col_index=$(get_column_index "$db_name" "$table_name" "$col_name")
        if [ -z "$col_index" ]; then
            echo "Error: Column '$col_name' not found in table '$table_name'"
            return
        fi
        col_indices+=("$col_index")
        col_names_display+=("$col_name")
    done
    
    header=$(IFS='|'; echo "${col_names_display[*]}")
    
    if [ -s "$data_file" ]; then
        cut_fields=$(IFS=,; echo "${col_indices[*]}")
        
        formatted_output=$( (echo "$header"; cut -d'|' -f"$cut_fields" "$data_file") | column -t -s '|' )
        
        echo "====================================="
        echo "     Selected Columns from $table_name"
        echo "====================================="
        echo "$formatted_output" | head -1
        echo "-------------------------------------"
        if [ $(echo "$formatted_output" | wc -l) -gt 1 ]; then
            echo "$formatted_output" | tail -n +2
        fi
        echo "-------------------------------------"
        echo "Total records: $(wc -l < "$data_file")"
    else
        echo "No data found!"
    fi
}

parse_where_clause() {
    local db_name="$1"
    local table_name="$2"
    local where_clause="$3"
    local columns="$4"  # "all" or column names
    
    where_clause=$(echo "$where_clause" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    if [[ "$where_clause" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
        local where_col="${BASH_REMATCH[1]}"
        local where_value="${BASH_REMATCH[2]}"
        
        where_value=$(echo "$where_value" | sed -e "s/^[[:space:]]*//" -e "s/[[:space:]]*$//" -e "s/^'//" -e "s/'$//")
        
        local col_index=$(get_column_index "$db_name" "$table_name" "$where_col")
        
        if [ -z "$col_index" ]; then
            echo "Error: Column '$where_col' not found in table '$table_name'"
            return
        fi
        
        if [ "$columns" == "all" ]; then
            select_where_sql "$db_name" "$table_name" "$col_index" "$where_value"
        else
            select_where_columns_sql "$db_name" "$table_name" "$col_index" "$where_value" "$columns"
        fi
        
    else
        echo "Error: Invalid WHERE clause syntax"
        echo "Usage: WHERE column = value"
    fi
}

select_where_sql() {
    local db_name="$1"
    local table_name="$2"
    local where_col_index="$3"
    local where_value="$4"
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    if [ ! -f "$meta_file" ]; then
        echo "Error: Table '$table_name' does not exist!"
        return
    fi
    
    source <(grep -v '^$' "$meta_file" | sed 's/:/=/')
    
    header=""
    for ((i=1; i<=col_count; i++)); do
        col_name_var="col${i}_name"
        header+="${!col_name_var}"
        if [ $i -lt $col_count ]; then
            header+="|"
        fi
    done
    
    if [ -s "$data_file" ]; then
        temp_file=$(mktemp)
        
        awk -F'|' -v wcol="$where_col_index" -v value="$where_value" '
        $wcol == value {print $0}
        ' "$data_file" > "$temp_file"
        
        if [ -s "$temp_file" ]; then
            formatted_output=$( (echo "$header"; cat "$temp_file") | column -t -s '|' )
            
            echo "====================================="
            echo "     Data from $table_name WHERE condition"
            echo "====================================="
            echo "$formatted_output" | head -1
            echo "-------------------------------------"
            echo "$formatted_output" | tail -n +2
            echo "-------------------------------------"
            echo "Matching records: $(wc -l < "$temp_file")"
        else
            echo "$header" | column -t -s '|'
            echo "-------------------------------------"
            echo "No matching records found!"
        fi
        
        rm "$temp_file"
    else
        echo "No data found!"
    fi
}

select_where_columns_sql() {
    local db_name="$1"
    local table_name="$2"
    local where_col_index="$3"
    local where_value="$4"
    local columns="$5"
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    if [ ! -f "$meta_file" ]; then
        echo "Error: Table '$table_name' does not exist!"
        return
    fi
    
    IFS=' ' read -ra col_array <<< "$columns"
    
    declare -a col_indices
    declare -a col_names_display
    
    for col_name in "${col_array[@]}"; do
        col_index=$(get_column_index "$db_name" "$table_name" "$col_name")
        if [ -z "$col_index" ]; then
            echo "Error: Column '$col_name' not found in table '$table_name'"
            return
        fi
        col_indices+=("$col_index")
        col_names_display+=("$col_name")
    done
    
    header=$(IFS='|'; echo "${col_names_display[*]}")
    
    if [ -s "$data_file" ]; then
        temp_file=$(mktemp)
        
        awk -F'|' -v wcol="$where_col_index" -v value="$where_value" -v fields="${col_indices[*]}" '
        BEGIN {
            split(fields, f, " ")
            OFS="|"
        }
        $wcol == value {
            output = ""
            for (i=1; i<=length(f); i++) {
                if (i > 1) output = output OFS
                output = output $f[i]
            }
            print output
        }
        ' "$data_file" > "$temp_file"
        
        if [ -s "$temp_file" ]; then
            formatted_output=$( (echo "$header"; cat "$temp_file") | column -t -s '|' )
            
            echo "====================================="
            echo "     Selected Columns from $table_name WHERE condition"
            echo "====================================="
            echo "$formatted_output" | head -1
            echo "-------------------------------------"
            echo "$formatted_output" | tail -n +2
            echo "-------------------------------------"
            echo "Matching records: $(wc -l < "$temp_file")"
        else
            echo "No matching records found!"
        fi
        
        rm "$temp_file"
    else
        echo "No data found!"
    fi
}

parse_update() {
    local sql_cmd="$1"
    
    if [ -z "$SQL_CURRENT_DB" ]; then
        echo "Error: No database selected. Use 'USE database_name;' first."
        return
    fi
    
    if [[ "$sql_cmd" =~ ^[Uu][Pp][Dd][Aa][Tt][Ee][[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]+[Ss][Ee][Tt][[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.+)[[:space:]]+[Ww][Hh][Ee][Rr][Ee][[:space:]]+(.+)$ ]]; then
        local table_name="${BASH_REMATCH[1]}"
        local update_col="${BASH_REMATCH[2]}"
        local new_value="${BASH_REMATCH[3]}"
        local where_clause="${BASH_REMATCH[4]}"
        
        new_value=$(echo "$new_value" | sed -e "s/^[[:space:]]*//" -e "s/[[:space:]]*$//" -e "s/^'//" -e "s/'$//")
        
        if [[ "$where_clause" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            local where_col="${BASH_REMATCH[1]}"
            local where_value="${BASH_REMATCH[2]}"
            
            where_value=$(echo "$where_value" | sed -e "s/^[[:space:]]*//" -e "s/[[:space:]]*$//" -e "s/^'//" -e "s/'$//")
            
            update_table_sql "$SQL_CURRENT_DB" "$table_name" "$update_col" "$new_value" "$where_col" "$where_value"
            
        else
            echo "Error: Invalid WHERE clause in UPDATE"
        fi
        
    else
        echo "Error: Invalid UPDATE syntax"
        echo "Usage: UPDATE table_name SET column = value WHERE column = value;"
    fi
}

update_table_sql() {
    local db_name="$1"
    local table_name="$2"
    local update_col="$3"
    local new_value="$4"
    local where_col="$5"
    local where_value="$6"
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    if [ ! -f "$meta_file" ]; then
        echo "Error: Table '$table_name' does not exist!"
        return
    fi
    
    local update_col_index=$(get_column_index "$db_name" "$table_name" "$update_col")
    local where_col_index=$(get_column_index "$db_name" "$table_name" "$where_col")
    
    if [ -z "$update_col_index" ]; then
        echo "Error: Column '$update_col' not found!"
        return
    fi
    
    if [ -z "$where_col_index" ]; then
        echo "Error: Column '$where_col' not found!"
        return
    fi
    
    local col_type=$(grep "^col${update_col_index}_type:" "$meta_file" | cut -d: -f2)
    
    if [ "$col_type" == "int" ] && [[ ! "$new_value" =~ ^-?[0-9]+$ ]]; then
        echo "Error: Column '$update_col' must be integer, got '$new_value'"
        return
    fi
    
    local is_primary=$(grep "^col${update_col_index}_primary:" "$meta_file" | cut -d: -f2)
    
    if [ "$is_primary" -eq 1 ]; then
        temp_file=$(mktemp)
        while IFS= read -r line; do
            IFS='|' read -ra fields <<< "$line"
            if [ "${fields[$((where_col_index-1))]}" != "$where_value" ] && [ "${fields[$((update_col_index-1))]}" == "$new_value" ]; then
                echo "Error: Primary key '$new_value' already exists in another record!"
                rm "$temp_file"
                return
            fi
        done < "$data_file"
        rm "$temp_file"
    fi
    
    temp_file=$(mktemp)
    updated_count=0
    
    while IFS= read -r line; do
        IFS='|' read -ra fields <<< "$line"
        
        if [ "${fields[$((where_col_index-1))]}" == "$where_value" ]; then
            fields[$((update_col_index-1))]="$new_value"
            updated_line=$(IFS='|'; echo "${fields[*]}")
            echo "$updated_line" >> "$temp_file"
            ((updated_count++))
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$data_file"
    
    mv "$temp_file" "$data_file"
    echo "$updated_count row(s) updated successfully!"
}

parse_delete() {
    local sql_cmd="$1"
    
    if [ -z "$SQL_CURRENT_DB" ]; then
        echo "Error: No database selected. Use 'USE database_name;' first."
        return
    fi
    
    if [[ "$sql_cmd" =~ ^[Dd][Ee][Ll][Ee][Tt][Ee][[:space:]]+[Ff][Rr][Oo][Mm][[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]+[Ww][Hh][Ee][Rr][Ee][[:space:]]+(.+)$ ]]; then
        local table_name="${BASH_REMATCH[1]}"
        local where_clause="${BASH_REMATCH[2]}"
        
        if [[ "$where_clause" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            local where_col="${BASH_REMATCH[1]}"
            local where_value="${BASH_REMATCH[2]}"
            
            where_value=$(echo "$where_value" | sed -e "s/^[[:space:]]*//" -e "s/[[:space:]]*$//" -e "s/^'//" -e "s/'$//")
            
            delete_from_table_sql "$SQL_CURRENT_DB" "$table_name" "$where_col" "$where_value"
            
        else
            echo "Error: Invalid WHERE clause in DELETE"
        fi
        
    else
        echo "Error: Invalid DELETE syntax"
        echo "Usage: DELETE FROM table_name WHERE column = value;"
    fi
}

delete_from_table_sql() {
    local db_name="$1"
    local table_name="$2"
    local where_col="$3"
    local where_value="$4"
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    if [ ! -f "$meta_file" ]; then
        echo "Error: Table '$table_name' does not exist!"
        return
    fi
    
    local where_col_index=$(get_column_index "$db_name" "$table_name" "$where_col")
    
    if [ -z "$where_col_index" ]; then
        echo "Error: Column '$where_col' not found!"
        return
    fi
    
    temp_file=$(mktemp)
    deleted_count=0
    
    while IFS= read -r line; do
        IFS='|' read -ra fields <<< "$line"
        
        if [ "${fields[$((where_col_index-1))]}" == "$where_value" ]; then
            ((deleted_count++))
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$data_file"
    
    mv "$temp_file" "$data_file"
    echo "$deleted_count row(s) deleted successfully!"
}

parse_drop_table() {
    local sql_cmd="$1"
    
    if [ -z "$SQL_CURRENT_DB" ]; then
        echo "Error: No database selected. Use 'USE database_name;' first."
        return
    fi
    
    if [[ "$sql_cmd" =~ ^[Dd][Rr][Oo][Pp][[:space:]]+[Tt][Aa][Bb][Ll][Ee][[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)$ ]]; then
        local table_name="${BASH_REMATCH[1]}"
        
        local meta_file="$DB_DIR/$SQL_CURRENT_DB/${table_name}_meta"
        local data_file="$DB_DIR/$SQL_CURRENT_DB/${table_name}_data"
        
        if [ -f "$meta_file" ]; then
            rm "$meta_file" "$data_file"
            echo "Table '$table_name' dropped successfully!"
        else
            echo "Error: Table '$table_name' does not exist!"
        fi
        
    else
        echo "Error: Invalid DROP TABLE syntax"
        echo "Usage: DROP TABLE table_name;"
    fi
}

parse_drop_database() {
    local sql_cmd="$1"
    
    if [[ "$sql_cmd" =~ ^[Dd][Rr][Oo][Pp][[:space:]]+[Dd][Aa][Tt][Aa][Bb][Aa][Ss][Ee][[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\;?$ ]]; then
        local db_name="${BASH_REMATCH[1]}"
        
        if [ -d "$DB_DIR/$db_name" ]; then
            if [ "$SQL_CURRENT_DB" == "$db_name" ]; then
                SQL_CURRENT_DB=""
            fi
            
            rm -r "$DB_DIR/$db_name"
            echo "Database '$db_name' dropped successfully!"
        else
            echo "Error: Database '$db_name' does not exist!"
        fi
        
    else
        echo "Error: Invalid DROP DATABASE syntax"
        echo "Usage: DROP DATABASE database_name;"
    fi
}