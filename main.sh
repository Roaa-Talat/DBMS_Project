#!/bin/bash

# Source the shared DBMS library
if [ -f "dbms_lib.sh" ]; then
    source "dbms_lib.sh"
else
    echo "Error: dbms_lib.sh not found!"
    exit 1
fi

# Initialize database directory
init_db_dir

# Global variable for current database
CURRENT_DB=""

# Initialize SQL_CURRENT_DB for SQL mode
SQL_CURRENT_DB=""

# Source the SQL parser
if [ -f "sql_parser.sh" ]; then
    source "sql_parser.sh"
    SQL_PARSER_AVAILABLE=1
else
    echo "Warning: SQL parser not found. SQL mode disabled."
    SQL_PARSER_AVAILABLE=0
fi

# Main menu function
main_menu() {
    while true; do
        echo "====================================="
        echo "     Bash Shell Script DBMS"
        echo "====================================="
        echo "1. Create Database"
        echo "2. List Databases"
        echo "3. Connect to Database"
        echo "4. Drop Database"
        echo "5. Exit"
        echo "6. SQL Mode"
        echo "====================================="
        read -p "Enter your choice [1-6]: " choice

        case $choice in
            1) cli_create_database ;;
            2) cli_list_databases ;;
            3) connect_database ;;
            4) cli_drop_database ;;
            5) echo "Goodbye!"; exit 0 ;;
            6) if [ $SQL_PARSER_AVAILABLE -eq 1 ]; then sql_parser; else echo "SQL parser not available!"; fi ;;
            *) echo "Invalid choice! Please try again." ;;
        esac
    done
}

# CLI wrapper functions
cli_create_database() {
    read -p "Enter database name: " db_name
    create_database "$db_name"
}

cli_list_databases() {
    echo "====================================="
    echo "          Available Databases"
    echo "====================================="
    list_databases
}

connect_database() {
    read -p "Enter database name to connect: " db_name

    if database_exists "$db_name"; then
        clear
        echo "Connected to database '$db_name'"
        table_menu "$db_name"
    else
        echo "Error: Database '$db_name' does not exist!"
    fi
}

cli_drop_database() {
    read -p "Enter database name to drop: " db_name
    drop_database "$db_name"
}

table_menu() {
    local db_name=$1

    while true; do
        echo "====================================="
        echo "     Database: $db_name"
        echo "====================================="
        echo "1. Create Table"
        echo "2. List Tables"
        echo "3. Drop Table"
        echo "4. Insert into Table"
        echo "5. Select From Table"
        echo "6. Delete From Table"
        echo "7. Update Table"
        echo "8. Back to Main Menu"
        echo "====================================="
        read -p "Enter your choice [1-8]: " choice

        case $choice in
            1) cli_create_table "$db_name" ;;
            2) cli_list_tables "$db_name" ;;
            3) cli_drop_table "$db_name" ;;
            4) cli_insert_into_table "$db_name" ;;
            5) cli_select_from_table "$db_name" ;;
            6) cli_delete_from_table "$db_name" ;;
            7) cli_update_table "$db_name" ;;
            8) return ;;
            *) echo "Invalid choice! Please try again." ;;
        esac
    done
}

# Create table function (CLI wrapper)
cli_create_table() {
    local db_name=$1
    read -p "Enter table name: " table_name

    # Validate table name
    if [[ ! "$table_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        echo "Error: Table name must start with a letter or underscore and contain only alphanumeric characters."
        return
    fi

    if table_exists "$db_name" "$table_name"; then
        echo "Error: Table '$table_name' already exists!"
        return
    fi

    # Get number of columns
    while true; do
        read -p "Enter number of columns: " col_count
        if [[ "$col_count" =~ ^[1-9][0-9]*$ ]]; then
            break
        else
            echo "Error: Please enter a positive integer!"
        fi
    done

    # Get column details
    declare -a col_names
    declare -a col_types
    declare -a is_primary

    echo "Enter column details:"
    primary_key_set=0

    for ((i=1; i<=col_count; i++)); do
        while true; do
            read -p "Column $i name: " col_name
            if [[ "$col_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                if [[ " ${col_names[@]} " =~ " ${col_name} " ]]; then
                    echo "Error: Column name '$col_name' already exists!"
                else
                    col_names[$i]=$col_name
                    break
                fi
            else
                echo "Error: Column name must start with a letter or underscore and contain only alphanumeric characters."
            fi
        done

        while true; do
            read -p "Column $i type (string/int): " col_type
            col_type_lower=$(echo "$col_type" | tr '[:upper:]' '[:lower:]')
            if [[ "$col_type_lower" == "string" || "$col_type_lower" == "int" ]]; then
                col_types[$i]=$col_type_lower
                break
            else
                echo "Error: Type must be 'string' or 'int'!"
            fi
        done

        if [ $primary_key_set -eq 0 ]; then
            while true; do
                read -p "Is this column the primary key? (y/n): " primary_choice
                if [[ "$primary_choice" == "y" || "$primary_choice" == "Y" ]]; then
                    is_primary[$i]=1
                    primary_key_set=1
                    echo "Primary key set to '$col_name'"
                    break
                elif [[ "$primary_choice" == "n" || "$primary_choice" == "N" ]]; then
                    is_primary[$i]=0
                    break
                else
                    echo "Invalid input. Please enter 'y' or 'n'."
                fi
            done
        else
            is_primary[$i]=0
        fi
    done

    if [ $primary_key_set -eq 0 ]; then
        echo "No primary key selected. You must choose a primary key column."
        echo "Available columns:"
        for ((i=1; i<=col_count; i++)); do
            echo "$i. ${col_names[$i]}"
        done
        while true; do
            read -p "Enter column number for primary key: " pk_choice
            if [[ "$pk_choice" =~ ^[1-9][0-9]*$ ]] && [ "$pk_choice" -le "$col_count" ]; then
                is_primary[$pk_choice]=1
                echo "Primary key set to '${col_names[$pk_choice]}'"
                break
            else
                echo "Error: Please enter a valid column number (1-$col_count)"
            fi
        done
    fi

    # Call library function
    create_table "$db_name" "$table_name" "$col_count" "${col_names[@]:1}" "${col_types[@]:1}" "${is_primary[@]:1}"
}

# List tables function (CLI wrapper)
cli_list_tables() {
    local db_name=$1
    echo "====================================="
    echo "          Tables in $db_name"
    echo "====================================="
    list_tables "$db_name"
}

# Drop table function (CLI wrapper)
cli_drop_table() {
    local db_name=$1
    read -p "Enter table name to drop: " table_name
    drop_table "$db_name" "$table_name"
}

# Insert into table function (CLI wrapper)
cli_insert_into_table() {
    local db_name=$1
    read -p "Enter table name: " table_name

    if ! table_exists "$db_name" "$table_name"; then
        echo "Error: Table '$table_name' does not exist!"
        return
    fi

    get_table_metadata "$db_name" "$table_name"

    declare -a values
    echo "Enter values for each column:"

    for ((i=1; i<=col_count; i++)); do
        col_name_var="col${i}_name"
        col_type_var="col${i}_type"
        col_primary_var="col${i}_primary"

        col_name=${!col_name_var}
        col_type=${!col_type_var}
        is_primary=${!col_primary_var}

        while true; do
            read -p "$col_name ($col_type): " value

            if [ "$is_primary" -eq 1 ] && [ -z "$value" ]; then
                echo "Error: Primary key '$col_name' cannot be empty!"
                continue
            fi

            if [ -z "$value" ]; then
                values[$i]=""
                break
            fi

            if [ "$col_type" == "int" ] && [[ ! "$value" =~ ^-?[0-9]+$ ]]; then
                echo "Error: $col_name must be an integer!"
                continue
            fi

            values[$i]=$value
            break
        done
    done

    insert_into_table "$db_name" "$table_name" "${values[@]:1}"
}

# Select from table function (CLI wrapper)
cli_select_from_table() {
    local db_name=$1
    read -p "Enter table name: " table_name

    if ! table_exists "$db_name" "$table_name"; then
        echo "Error: Table '$table_name' does not exist!"
        return
    fi

    echo "====================================="
    echo "          Select From $table_name"
    echo "====================================="
    echo "1. Select All Data"
    echo "2. Select Specific Columns"
    echo "3. Select With Condition (WHERE)"
    echo "4. Select Specific Columns with Condition"
    echo "====================================="
    read -p "Enter your choice [1-4]: " select_choice

    case $select_choice in
        1) cli_select_all "$db_name" "$table_name" ;;
        2) cli_select_columns "$db_name" "$table_name" ;;
        3) cli_select_where "$db_name" "$table_name" ;;
        4) cli_select_columns_where "$db_name" "$table_name" ;;
        *) echo "Invalid choice! Showing all data by default."; cli_select_all "$db_name" "$table_name" ;;
    esac
}

# Select all data function (CLI wrapper)
cli_select_all() {
    local db_name=$1
    local table_name=$2

    get_table_metadata "$db_name" "$table_name"

    header=""
    for ((i=1; i<=col_count; i++)); do
        col_name_var="col${i}_name"
        header+="${!col_name_var}"
        if [ $i -lt $col_count ]; then
            header+="|"
        fi
    done

    echo "====================================="
    echo "          All Data from $table_name"
    echo "====================================="

    local data_file="$DB_DIR/$db_name/${table_name}_data"
    if [ -s "$data_file" ]; then
        formatted_output=$( (echo "$header"; cat "$data_file") | column -t -s '|' )
        echo "$formatted_output" | head -1
        echo "-------------------------------------"
        echo "$formatted_output" | tail -n +2
        echo "-------------------------------------"
        echo "Total records: $(wc -l < "$data_file")"
    else
        echo "No data found!"
    fi
}

# Select specific columns function (CLI wrapper)
cli_select_columns() {
    local db_name=$1
    local table_name=$2

    get_table_metadata "$db_name" "$table_name"

    echo "Available columns:"
    for ((i=1; i<=col_count; i++)); do
        col_name_var="col${i}_name"
        echo "$i. ${!col_name_var}"
    done

    read -p "Enter column numbers to select (e.g., 1,3,4): " col_selection

    declare -a selected_cols
    if [[ "$col_selection" =~ ^[0-9,]+$ ]]; then
        IFS=',' read -ra selected_cols <<< "$col_selection"
    else
        echo "Invalid selection! Showing all columns."
        cli_select_all "$db_name" "$table_name"
        return
    fi

    valid_cols=()
    for col in "${selected_cols[@]}"; do
        if [ $col -ge 1 ] && [ $col -le $col_count ]; then
            valid_cols+=($col)
        else
            echo "Warning: Column $col is invalid. Skipping."
        fi
    done

    if [ ${#valid_cols[@]} -eq 0 ]; then
        echo "No valid columns selected! Showing all columns."
        cli_select_all "$db_name" "$table_name"
        return
    fi

    declare -a col_names
    for i in "${valid_cols[@]}"; do
        col_name_var="col${i}_name"
        col_names+=("${!col_name_var}")
    done

    select_columns "$db_name" "$table_name" "${col_names[@]}"
}

# Select with WHERE condition function (CLI wrapper)
cli_select_where() {
    local db_name=$1
    local table_name=$2

    get_table_metadata "$db_name" "$table_name"

    echo "Available columns:"
    for ((i=1; i<=col_count; i++)); do
        col_name_var="col${i}_name"
        col_type_var="col${i}_type"
        echo "$i. ${!col_name_var} (${!col_type_var})"
    done

    read -p "Enter column number for WHERE condition: " where_col
    if [[ ! "$where_col" =~ ^[1-9][0-9]*$ ]] || [ "$where_col" -gt "$col_count" ]; then
        echo "Error: Invalid column number!"
        return
    fi

    read -p "Enter value to match: " where_value

    col_name_var="col${where_col}_name"
    echo "====================================="
    echo "     Data from $table_name WHERE ${!col_name_var} = $where_value"
    echo "====================================="

    select_where "$db_name" "$table_name" "$where_col" "$where_value"
}

# Select specific columns with condition (CLI wrapper)
cli_select_columns_where() {
    local db_name=$1
    local table_name=$2

    get_table_metadata "$db_name" "$table_name"

    echo "Available columns:"
    for ((i=1; i<=col_count; i++)); do
        col_name_var="col${i}_name"
        col_type_var="col${i}_type"
        echo "$i. ${!col_name_var} (${!col_type_var})"
    done

    read -p "Enter column number to search in: " where_col
    if [[ ! "$where_col" =~ ^[1-9][0-9]*$ ]] || [ "$where_col" -gt "$col_count" ]; then
        echo "Error: Invalid column number!"
        return
    fi

    col_name_var="col${where_col}_name"
    read -p "Enter value to match in '${!col_name_var}': " where_value

    columns=()
    for ((i=1; i<=col_count; i++)); do
        col_name_var="col${i}_name"
        columns+=("${!col_name_var}")
    done

    echo "--- Columns to Display ---"
    for i in "${!columns[@]}"; do
        echo "$((i+1))) ${columns[$i]}"
    done

    read -p "Enter column numbers to display (e.g., 1 3): " -a choice_cols

    declare -a display_cols
    for c in "${choice_cols[@]}"; do
        display_cols+=("${columns[$((c-1))]}")
    done

    echo "----- Matching Rows -----"

    local where_col_index=$where_col

    local data_file="$DB_DIR/$db_name/${table_name}_data"
    local temp_file=$(mktemp)

    while IFS='|' read -ra fields; do
        if [ "${fields[$((where_col_index-1))]}" == "$where_value" ]; then
            row=""
            for c in "${choice_cols[@]}"; do
                if [[ -n "$row" ]]; then
                    row+="|${fields[$((c-1))]}"
                else
                    row+="${fields[$((c-1))]}"
                fi
            done
            echo "$row" >> "$temp_file"
        fi
    done < "$data_file"

    header=$(IFS='|'; echo "${display_cols[*]}")

    if [ -s "$temp_file" ]; then
        formatted_output=$( (echo "$header"; cat "$temp_file") | column -t -s '|' )
        echo "$formatted_output" | head -1
        echo "-------------------------------------"
        echo "$formatted_output" | tail -n +2
        echo "-------------------------------------"
        echo "Matching records: $(wc -l < "$temp_file")"
    else
        echo "$header" | column -t -s '|'
        echo "-------------------------------------"
        echo "No matching records found!"
        echo "-------------------------------------"
        echo "Matching records: 0"
    fi

    rm -f "$temp_file"
}
# Delete from table function (CLI wrapper)
cli_delete_from_table() {
    local db_name=$1
    read -p "Enter table name: " table_name

    if ! table_exists "$db_name" "$table_name"; then
        echo "Error: Table '$table_name' does not exist!"
        return
    fi

    echo "1. Delete by condition"
    echo "2. Delete all data"
    read -p "Enter your choice [1-2]: " choice

    case $choice in
        1) cli_delete_by_condition "$db_name" "$table_name" ;;
        2) cli_delete_all_data "$db_name" "$table_name" ;;
        *) echo "Invalid choice!" ;;
    esac
}

# Delete by condition function (CLI wrapper)
cli_delete_by_condition() {
    local db_name=$1
    local table_name=$2

    get_table_metadata "$db_name" "$table_name"

    echo "Available columns:"
    for ((i=1; i<=col_count; i++)); do
        col_name_var="col${i}_name"
        echo "$i. ${!col_name_var}"
    done

    read -p "Enter column number to search: " col_num
    if [[ ! "$col_num" =~ ^[1-9][0-9]*$ ]] || [ "$col_num" -gt "$col_count" ]; then
        echo "Error: Invalid column number!"
        return 1
    fi

    col_name_var="col${col_num}_name"
    read -p "Enter value to delete: " search_value

    delete_from_table "$db_name" "$table_name" "${!col_name_var}" "$search_value"
}

# Delete all data function (CLI wrapper)
cli_delete_all_data() {
    local db_name=$1
    local table_name=$2

    local data_file="$DB_DIR/$db_name/${table_name}_data"

    read -p "Are you sure you want to delete all data from $table_name? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        > "$data_file"
        echo "All data deleted from '$table_name'!"
    else
        echo "Operation cancelled."
    fi
}

# Update table function (CLI wrapper)
cli_update_table() {
    local db_name=$1
    read -p "Enter table name: " table_name

    if ! table_exists "$db_name" "$table_name"; then
        echo "Error: Table '$table_name' does not exist!"
        return
    fi

    get_table_metadata "$db_name" "$table_name"

    echo "Available columns:"
    for ((i=1; i<=col_count; i++)); do
        col_name_var="col${i}_name"
        col_type_var="col${i}_type"
        col_primary_var="col${i}_primary"
        primary_status=""
        if [ "${!col_primary_var}" -eq 1 ]; then
            primary_status=" (PRIMARY KEY)"
        fi
        echo "$i. ${!col_name_var} (${!col_type_var})$primary_status"
    done

    read -p "Enter column number to search for record: " search_col
    if [[ ! "$search_col" =~ ^[1-9][0-9]*$ ]] || [ "$search_col" -gt "$col_count" ]; then
        echo "Error: Invalid column number!"
        return
    fi

    col_name_var="col${search_col}_name"
    read -p "Enter value to search: " search_value

    read -p "Enter column number to update: " update_col
    if [[ ! "$update_col" =~ ^[1-9][0-9]*$ ]] || [ "$update_col" -gt "$col_count" ]; then
        echo "Error: Invalid column number!"
        return
    fi

    col_primary_var="col${update_col}_primary"
    if [ "${!col_primary_var}" -eq 1 ]; then
        echo "WARNING: You are updating a PRIMARY KEY column!"
        read -p "Are you sure you want to update the primary key? (y/n): " confirm_pk
        if [[ ! "$confirm_pk" =~ ^[Yy]$ ]]; then
            echo "Update cancelled."
            return
        fi
    fi

    while true; do
        read -p "Enter new value: " new_value

        if [ -z "$new_value" ]; then
            if [ "${!col_primary_var}" -eq 1 ]; then
                echo "Error: Primary key cannot be null or empty!"
                continue
            else
                echo "Warning: Setting value to empty. Continue? (y/n): "
                read confirm_empty
                if [[ "$confirm_empty" =~ ^[Yy]$ ]]; then
                    break
                else
                    continue
                fi
            fi
        fi

        col_type_var="col${update_col}_type"
        col_type=${!col_type_var}

        if [ "$col_type" == "int" ] && [[ ! "$new_value" =~ ^-?[0-9]+$ ]]; then
            echo "Error: The column must contain integer values!"
            continue
        fi

        break
    done

    update_col_name_var="col${update_col}_name"
    update_table "$db_name" "$table_name" "${!update_col_name_var}" "$new_value" "${!col_name_var}" "$search_value"
}

echo "Starting Bash Shell Script DBMS..."
main_menu