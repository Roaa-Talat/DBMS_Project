#!/bin/bash

# DBMS Shared Library
# Contains common database operations used by CLI, GUI, and SQL parser

# Database directory
DB_DIR="databases"

# Initialize database directory
init_db_dir() {
    mkdir -p "$DB_DIR"
}

# ============================================
# DATABASE OPERATIONS
# ============================================

create_database() {
    local db_name="$1"
    
    if [[ ! "$db_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        echo "Error: Database name must start with a letter or underscore and contain only alphanumeric characters."
        return 1
    fi
    
    if [ -d "$DB_DIR/$db_name" ]; then
        echo "Error: Database '$db_name' already exists!"
        return 1
    fi
    
    mkdir -p "$DB_DIR/$db_name"
    echo "Database '$db_name' created successfully!"
    return 0
}

list_databases() {
    if [ -d "$DB_DIR" ] && [ "$(ls -A "$DB_DIR" 2>/dev/null)" ]; then
        ls -1 "$DB_DIR"
    else
        echo "No databases found!"
    fi
}

drop_database() {
    local db_name="$1"
    
    if [ -d "$DB_DIR/$db_name" ]; then
        rm -r "$DB_DIR/$db_name"
        echo "Database '$db_name' dropped successfully!"
        return 0
    else
        echo "Error: Database '$db_name' does not exist!"
        return 1
    fi
}

# ============================================
# TABLE OPERATIONS
# ============================================

create_table() {
    local db_name="$1"
    local table_name="$2"
    shift 2
    
    local col_count=$1
    shift
    
    local col_names=()
    local col_types=()
    local is_primary=()
    
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
        return 1
    fi
    
    echo "col_count:$col_count" > "$meta_file"
    for ((i=0; i<col_count; i++)); do
        echo "col$((i+1))_name:${col_names[$i]}" >> "$meta_file"
        echo "col$((i+1))_type:${col_types[$i]}" >> "$meta_file"
        echo "col$((i+1))_primary:${is_primary[$i]}" >> "$meta_file"
    done
    
    touch "$data_file"
    echo "Table '$table_name' created successfully!"
    return 0
}

list_tables() {
    local db_name="$1"
    local db_path="$DB_DIR/$db_name"
    
    if ls "$db_path"/*_meta 2>/dev/null 1>&2; then
        while IFS= read -r meta_file; do
            basename "$meta_file" _meta
        done < <(ls "$db_path"/*_meta)
    else
        echo "No tables found!"
    fi
}

drop_table() {
    local db_name="$1"
    local table_name="$2"
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    if [ -f "$meta_file" ]; then
        rm "$meta_file" "$data_file"
        echo "Table '$table_name' dropped successfully!"
        return 0
    else
        echo "Error: Table '$table_name' does not exist!"
        return 1
    fi
}

# ============================================
# DATA OPERATIONS
# ============================================

insert_into_table() {
    local db_name="$1"
    local table_name="$2"
    shift 2
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    if [ ! -f "$meta_file" ]; then
        echo "Error: Table '$table_name' does not exist!"
        return 1
    fi
    
    local col_count=$(grep "^col_count:" "$meta_file" | cut -d: -f2)
    
    if [ $# -ne $col_count ]; then
        echo "Error: Expected $col_count values, got $#"
        return 1
    fi
    
    declare -a values=("$@")
    
    for ((i=1; i<=col_count; i++)); do
        local col_type=$(grep "^col${i}_type:" "$meta_file" | cut -d: -f2)
        local is_primary=$(grep "^col${i}_primary:" "$meta_file" | cut -d: -f2)
        local value="${values[$((i-1))]}"
        
        if [ "$is_primary" -eq 1 ]; then
            if [ -z "$value" ]; then
                echo "Error: Primary key cannot be empty!"
                return 1
            fi
            
            if [ -f "$data_file" ]; then
                if cut -d'|' -f"$i" "$data_file" | grep -q "^$value$"; then
                    echo "Error: Primary key '$value' already exists!"
                    return 1
                fi
            fi
        fi
        
        if [ "$col_type" == "int" ] && [[ ! "$value" =~ ^-?[0-9]+$ ]]; then
            echo "Error: Column $i must be integer, got '$value'"
            return 1
        fi
    done
    
    local row_data=$(IFS='|'; echo "${values[*]}")
    echo "$row_data" >> "$data_file"
    echo "1 row inserted successfully!"
    return 0
}

select_all() {
    local db_name="$1"
    local table_name="$2"
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    if [ ! -f "$meta_file" ]; then
        echo "Error: Table '$table_name' does not exist!"
        return 1
    fi
    
    source <(grep -v '^$' "$meta_file" | sed 's/:/=/')
    
    local header=""
    for ((i=1; i<=col_count; i++)); do
        local col_name_var="col${i}_name"
        header+="${!col_name_var}"
        if [ $i -lt $col_count ]; then
            header+="|"
        fi
    done
    
    echo "$header"
    
    if [ -f "$data_file" ] && [ -s "$data_file" ]; then
        cat "$data_file"
    else
        echo "No data found!"
    fi
    
    echo "Total records: $(wc -l < "$data_file" 2>/dev/null || echo 0)"
    return 0
}

select_columns() {
    local db_name="$1"
    local table_name="$2"
    shift 2
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    if [ ! -f "$meta_file" ]; then
        echo "Error: Table '$table_name' does not exist!"
        return 1
    fi
    
    declare -a col_indices
    declare -a col_names_display
    
    for col_name in "$@"; do
        local col_index=$(get_column_index "$db_name" "$table_name" "$col_name")
        if [ -z "$col_index" ]; then
            echo "Error: Column '$col_name' not found in table '$table_name'"
            return 1
        fi
        col_indices+=("$col_index")
        col_names_display+=("$col_name")
    done
    
    local header=$(IFS='|'; echo "${col_names_display[*]}")
    
    if [ -s "$data_file" ]; then
        local cut_fields=$(IFS=,; echo "${col_indices[*]}")
        local formatted_output=$( (echo "$header"; cut -d'|' -f"$cut_fields" "$data_file") | column -t -s '|' )
        
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

select_where() {
    local db_name="$1"
    local table_name="$2"
    local where_col_index="$3"
    local where_value="$4"
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    if [ ! -f "$meta_file" ]; then
        echo "Error: Table '$table_name' does not exist!"
        return 1
    fi
    
    source <(grep -v '^$' "$meta_file" | sed 's/:/=/')
    
    local header=""
    for ((i=1; i<=col_count; i++)); do
        local col_name_var="col${i}_name"
        header+="${!col_name_var}"
        if [ $i -lt $col_count ]; then
            header+="|"
        fi
    done
    
    if [ -s "$data_file" ]; then
        local temp_file=$(mktemp)
        
        awk -F'|' -v wcol="$where_col_index" -v value="$where_value" '
        $wcol == value {print $0}
        ' "$data_file" > "$temp_file"
        
        if [ -s "$temp_file" ]; then
            local formatted_output=$( (echo "$header"; cat "$temp_file") | column -t -s '|' )
            
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

update_table() {
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
        return 1
    fi
    
    local update_col_index=$(get_column_index "$db_name" "$table_name" "$update_col")
    local where_col_index=$(get_column_index "$db_name" "$table_name" "$where_col")
    
    if [ -z "$update_col_index" ]; then
        echo "Error: Column '$update_col' not found!"
        return 1
    fi
    
    if [ -z "$where_col_index" ]; then
        echo "Error: Column '$where_col' not found!"
        return 1
    fi
    
    local col_type=$(grep "^col${update_col_index}_type:" "$meta_file" | cut -d: -f2)
    
    if [ "$col_type" == "int" ] && [[ ! "$new_value" =~ ^-?[0-9]+$ ]]; then
        echo "Error: Column '$update_col' must be integer, got '$new_value'"
        return 1
    fi
    
    local is_primary=$(grep "^col${update_col_index}_primary:" "$meta_file" | cut -d: -f2)
    
    if [ "$is_primary" -eq 1 ]; then
        local temp_file=$(mktemp)
        while IFS= read -r line; do
            IFS='|' read -ra fields <<< "$line"
            if [ "${fields[$((where_col_index-1))]}" != "$where_value" ] && [ "${fields[$((update_col_index-1))]}" == "$new_value" ]; then
                echo "Error: Primary key '$new_value' already exists in another record!"
                rm "$temp_file"
                return 1
            fi
        done < "$data_file"
        rm "$temp_file"
    fi
    
    local temp_file=$(mktemp)
    local updated_count=0
    
    while IFS= read -r line; do
        IFS='|' read -ra fields <<< "$line"
        
        if [ "${fields[$((where_col_index-1))]}" == "$where_value" ]; then
            fields[$((update_col_index-1))]="$new_value"
            local updated_line=$(IFS='|'; echo "${fields[*]}")
            echo "$updated_line" >> "$temp_file"
            ((updated_count++))
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$data_file"
    
    mv "$temp_file" "$data_file"
    echo "$updated_count row(s) updated successfully!"
    return 0
}

delete_from_table() {
    local db_name="$1"
    local table_name="$2"
    local where_col="$3"
    local where_value="$4"
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    if [ ! -f "$meta_file" ]; then
        echo "Error: Table '$table_name' does not exist!"
        return 1
    fi
    
    local where_col_index=$(get_column_index "$db_name" "$table_name" "$where_col")
    
    if [ -z "$where_col_index" ]; then
        echo "Error: Column '$where_col' not found!"
        return 1
    fi
    
    local temp_file=$(mktemp)
    local deleted_count=0
    
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
    return 0
}

# ============================================
# UTILITY FUNCTIONS
# ============================================

get_column_index() {
    local db_name="$1"
    local table_name="$2"
    local col_name="$3"
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    
    if [ ! -f "$meta_file" ]; then
        return
    fi
    
    for i in {1..100}; do
        local col_line=$(grep "^col${i}_name:" "$meta_file" 2>/dev/null)
        if [ -n "$col_line" ]; then
            local found_name=$(echo "$col_line" | cut -d: -f2)
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

get_table_metadata() {
    local db_name="$1"
    local table_name="$2"
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    
    if [ ! -f "$meta_file" ]; then
        return 1
    fi
    
    source <(grep -v '^$' "$meta_file" | sed 's/:/=/')
    return 0
}

table_exists() {
    local db_name="$1"
    local table_name="$2"
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    [ -f "$meta_file" ]
}

database_exists() {
    local db_name="$1"
    [ -d "$DB_DIR/$db_name" ]
}

# Export functions
export -f create_database
export -f list_databases
export -f drop_database
export -f create_table
export -f list_tables
export -f drop_table
export -f insert_into_table
export -f select_all
export -f select_columns
export -f select_where
export -f update_table
export -f delete_from_table
export -f get_column_index
export -f get_table_metadata
export -f table_exists
export -f database_exists
export -f init_db_dir
