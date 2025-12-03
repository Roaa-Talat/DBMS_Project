#!/bin/bash

# Database root directory
DB_DIR="databases"

# Add global variable for current database
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
            1) create_database ;;
            2) list_databases ;;
            3) connect_database ;;
            4) drop_database ;;
            5) echo "Goodbye!"; exit 0 ;;
            6) if [ $SQL_PARSER_AVAILABLE -eq 1 ]; then sql_parser; else echo "SQL parser not available!"; fi ;;
            *) echo "Invalid choice! Please try again." ;;
        esac
    done
}

# Create database function
create_database() {
    read -p "Enter database name: " db_name
    
    # Validate database name (only alphanumeric and underscores)
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
}

# List databases function
list_databases() {
    echo "====================================="
    echo "          Available Databases"
    echo "====================================="
    
    if [ -d "$DB_DIR" ] && [ "$(ls -A "$DB_DIR" 2>/dev/null)" ]; then
        ls -1 "$DB_DIR"
    else
        echo "No databases found!"
    fi
}

# Connect to database function
connect_database() {
    read -p "Enter database name to connect: " db_name
    
    if [ -d "$DB_DIR/$db_name" ]; then
        /usr/bin/clear  # new screen
        echo "Connected to database '$db_name'"
        table_menu "$db_name"
    else
        echo "Error: Database '$db_name' does not exist!"
    fi
}

# Drop database function
drop_database() {
    read -p "Enter database name to drop: " db_name
    
    if [ -d "$DB_DIR/$db_name" ]; then
        rm -r "$DB_DIR/$db_name"
        echo "Database '$db_name' dropped successfully!"
    else
        echo "Error: Database '$db_name' does not exist!"
    fi
}

# Table menu function
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
            1) create_table "$db_name" ;;
            2) list_tables "$db_name" ;;
            3) drop_table "$db_name" ;;
            4) insert_into_table "$db_name" ;;
            5) select_from_table "$db_name" ;;
            6) delete_from_table "$db_name" ;;
            7) update_table "$db_name" ;;
            8) return ;;
            *) echo "Invalid choice! Please try again." ;;
        esac
    done
}

# Create table function
create_table() {
    local db_name=$1
    read -p "Enter table name: " table_name
    
    # Validate table name
    if [[ ! "$table_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        echo "Error: Table name must start with a letter or underscore and contain only alphanumeric characters."
        return
    fi
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    if [ -f "$meta_file" ]; then
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
                # Check for duplicate column names
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
        
        # Get column type
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
        
        # Ask for primary key (for ALL columns including first one)
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
	    # If primary key already set, mark others as not primary
	    is_primary[$i]=0
	fi
    done
    
    # If no primary key was set, ask user to choose one
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
    
    # Save metadata
    echo "col_count:$col_count" > "$meta_file"
    for ((i=1; i<=col_count; i++)); do
        echo "col${i}_name:${col_names[$i]}" >> "$meta_file"
        echo "col${i}_type:${col_types[$i]}" >> "$meta_file"
        echo "col${i}_primary:${is_primary[$i]}" >> "$meta_file"
    done
    
    # Create empty data file
    touch "$data_file"
    echo "Table '$table_name' created successfully!"
}

# List tables function
list_tables() {
    local db_name=$1
    local db_path="./databases/$db_name"

    echo "====================================="
    echo "          Tables in $db_name"
    echo "====================================="

    local tables_found=0
    if ls "$db_path" | grep -Ev '(_meta$|~$)' >/dev/null 2>&1; then
       ls "$db_path" | grep -Ev '(_meta$|~$)'
    else 
        echo "No tables found!"
    fi
}

# Drop table function
drop_table() {
    local db_name=$1
    read -p "Enter table name to drop: " table_name
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    if [ -f "$meta_file" ]; then
        rm "$meta_file" "$data_file"
        echo "Table '$table_name' dropped successfully!"
    else
        echo "Error: Table '$table_name' does not exist!"
    fi
}

# Insert into table function
insert_into_table() {
    local db_name=$1
    read -p "Enter table name: " table_name
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    if [ ! -f "$meta_file" ]; then
        echo "Error: Table '$table_name' does not exist!"
        return
    fi
    
    # Read metadata
    source <(grep -v '^$' "$meta_file" | sed 's/:/=/')
    
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
            
            # Primary key validation - cannot be empty
            if [ "$is_primary" -eq 1 ]; then
                if [ -z "$value" ]; then
                    echo "Error: Primary key '$col_name' cannot be empty!"
                    continue
                fi
                
                # Check primary key uniqueness
                if grep -q "^$value|" "$data_file"; then
                    echo "Error: Primary key '$value' already exists!"
                    continue
                fi
            fi
            
            # For non-primary key columns, allow empty values
            if [ -z "$value" ]; then
                values[$i]=""
                break
            fi
            
            # Validate data type only if value is not empty
            if [ "$col_type" == "int" ] && [[ ! "$value" =~ ^-?[0-9]*$ ]]; then
                echo "Error: $col_name must be an integer!"
                continue
            fi
            
            values[$i]=$value
            break
        done
    done
    
    # Save to data file
    row_data=""
    for ((i=1; i<=col_count; i++)); do
        row_data+="${values[$i]}"
        if [ $i -lt $col_count ]; then
            row_data+="|"
        fi
    done
    
    echo "$row_data" >> "$data_file"
    echo "Record inserted successfully!"
}

# Select from table function
select_from_table() {
    local db_name=$1
    read -p "Enter table name: " table_name
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    if [ ! -f "$meta_file" ]; then
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
        1) select_all "$db_name" "$table_name" ;;
        2) select_columns "$db_name" "$table_name" ;;
        3) select_where "$db_name" "$table_name" ;;
        4) select_specific_column_with_condition "$db_name" "$table_name" ;;  # Add this line
        *) echo "Invalid choice! Showing all data by default."; select_all "$db_name" "$table_name" ;;
    esac
}

# Select all data function
select_all() {
    local db_name=$1
    local table_name=$2
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    # Read metadata
    source <(grep -v '^$' "$meta_file" | sed 's/:/=/')
    
    # Create header (with | separator)
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
    
    # Display data
    if [ -s "$data_file" ]; then
        # Format header and data together for proper alignment
        formatted_output=$( (echo "$header"; cat "$data_file") | column -t -s '|' )
        echo "$formatted_output" | head -1  # Show header
        echo "-------------------------------------"
        echo "$formatted_output" | tail -n +2  # Show data
        echo "-------------------------------------"
        echo "Total records: $(wc -l < "$data_file")"
    else
        echo "No data found!"
    fi
}

# Select specific columns function
select_columns() {
    local db_name=$1
    local table_name=$2
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    # Read metadata
    source <(grep -v '^$' "$meta_file" | sed 's/:/=/')
    
    # Show available columns
    echo "Available columns:"
    for ((i=1; i<=col_count; i++)); do
        col_name_var="col${i}_name"
        echo "$i. ${!col_name_var}"
    done
    
    read -p "Enter column numbers to select (e.g., 1,3,4): " col_selection
    
    # Parse column selection
    declare -a selected_cols
    if [[ "$col_selection" =~ ^[0-9,]+$ ]]; then
        IFS=',' read -ra selected_cols <<< "$col_selection"
    else
        echo "Invalid selection! Showing all columns."
        select_all "$db_name" "$table_name"
        return
    fi
    
    # Validate selected columns
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
        select_all "$db_name" "$table_name"
        return
    fi
    
    # Create header for selected columns (with | separator)
    header=""
    for i in "${valid_cols[@]}"; do
        col_name_var="col${i}_name"
        header+="${!col_name_var}"
        if [ $i -ne ${valid_cols[-1]} ]; then
            header+="|"
        fi
    done
    
    echo "====================================="
    echo "     Selected Columns from $table_name"
    echo "====================================="
    
    # Display selected columns data using cut command
    if [ -s "$data_file" ]; then
        cut_fields=$(IFS=,; echo "${valid_cols[*]}")
   
        formatted_output=$( (echo "$header"; cut -d'|' -f"$cut_fields" "$data_file") | column -t -s '|' )
        
        echo "$formatted_output" | head -1  # Show header
        echo "-------------------------------------"
        echo "$formatted_output" | tail -n +2  # Show data
        echo "-------------------------------------"
        echo "Total records: $(wc -l < "$data_file")"
    else
        echo "No data found!"
    fi
}

# Select with WHERE condition function
select_where() {
    local db_name=$1
    local table_name=$2
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    # Read metadata
    source <(grep -v '^$' "$meta_file" | sed 's/:/=/')
    
    # Show available columns
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
    col_type_var="col${where_col}_type"
    
    echo "====================================="
    echo "     Data from $table_name WHERE ${!col_name_var} = $where_value"
    echo "====================================="
    
    # Create header (with | separator)
    header=""
    for ((i=1; i<=col_count; i++)); do
        col_name_var="col${i}_name"
        header+="${!col_name_var}"
        if [ $i -lt $col_count ]; then
            header+="|"
        fi
    done
    
    # Filter and display data 
    if [ -s "$data_file" ]; then
        # match specific column
        matching_data=$(awk -F'|' -v col="$where_col" -v value="$where_value" '
            BEGIN {found=0}
            $col == value {
                print $0
                found=1
            }
            END {
                if (found == 0) exit 1
            }
        ' "$data_file")
        
        if [ $? -eq 0 ]; then
            # Format and display the data
            formatted_output=$(echo "$matching_data" | (echo "$header"; cat) | column -t -s '|')
            echo "$formatted_output" | head -1  # Show header
            echo "-------------------------------------"
            echo "$formatted_output" | tail -n +2  # Show data
            echo "-------------------------------------"
            
            # Count matching records
            count=$(echo "$matching_data" | wc -l)
            echo "Matching records: $count"
        else
            echo "$header" | column -t -s '|'
            echo "-------------------------------------"
            echo "No matching records found!"
            echo "-------------------------------------"
            echo "Matching records: 0"
        fi
    else
        echo "No data found!"
    fi
}

select_specific_column_with_condition() {
    local db_name=$1
    local table_name=$2
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    # Read metadata
    source <(grep -v '^$' "$meta_file" | sed 's/:/=/')
    
    # Show available columns
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
    col_type_var="col${where_col}_type"
	    
    read -p "Enter value to match in '${!col_name_var}': " where_value
    columns=()
    for ((i=1; i<=col_count; i++))
    do
        col_name_var="col${i}_name"    
        columns+=("${!col_name_var}")
    done

    echo "--- Columns to Display ---"
    for i in "${!columns[@]}"; do
        echo "$((i+1))) ${columns[$i]}"
    done

    read -p "Enter column numbers to display (e.g., 1 3): " -a choice_cols

    # Create header for selected columns
    header=""
    for c in "${choice_cols[@]}"; do
        if [[ -n "$header" ]]; then
            header+="|${columns[$((c-1))]}"
        else
            header+="${columns[$((c-1))]}"
        fi
    done

    echo
    echo "----- Matching Rows -----"

    # Create a temp file with filtered data
    temp_file=$(mktemp)
    
    # Filter records based on condition
    while IFS='|' read -ra fields; do
        if [ "${fields[$((where_col-1))]}" == "$where_value" ]; then
            # Build the output row with selected columns
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

    # Display the results
    if [ -s "$temp_file" ]; then
        formatted_output=$( (echo "$header"; cat "$temp_file") | column -t -s '|' )
        echo "$formatted_output" | head -1  # Show header
        echo "-------------------------------------"
        echo "$formatted_output" | tail -n +2  # Show data
        echo "-------------------------------------"
        echo "Matching records: $(wc -l < "$temp_file")"
    else
        echo "$header" | column -t -s '|'
        echo "-------------------------------------"
        echo "No matching records found!"
        echo "-------------------------------------"
        echo "Matching records: 0"
    fi
    
    # Clean up temp file
    rm -f "$temp_file"
}
# Delete from table function
delete_from_table() {
    local db_name=$1
    read -p "Enter table name: " table_name
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    if [ ! -f "$meta_file" ]; then
        echo "Error: Table '$table_name' does not exist!"
        return
    fi
    
    echo "1. Delete by condition"
    echo "2. Delete all data"
    read -p "Enter your choice [1-2]: " choice
    
    case $choice in
        1) delete_by_condition "$db_name" "$table_name" ;;
        2) delete_all_data "$db_name" "$table_name" ;;
        *) echo "Invalid choice!" ;;
    esac
}

# Delete by condition function
delete_by_condition() {
    local db_name=$1
    local table_name=$2
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    # Check if table exists
    if [[ ! -f "$meta_file" ]] || [[ ! -f "$data_file" ]]; then
        echo "Error: Table '$table_name' does not exist!"
        return 1
    fi
    
    # Read metadata
    source <(grep -v '^$' "$meta_file" | sed 's/:/=/')
    
    # Show available columns
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
    
    read -p "Enter value to delete: " search_value
    
    # Check if data file is empty
    if [[ ! -s "$data_file" ]]; then
        echo "No records found in table '$table_name'."
        return 0
    fi
    
    # Create temp file and delete matching rows
    temp_file=$(mktemp)
    deleted_count=0
    total_records=0
    
    while IFS= read -r line; do
        ((total_records++))
        IFS='|' read -ra fields <<< "$line"
        if [ "${fields[$((col_num-1))]}" != "$search_value" ]; then
            echo "$line" >> "$temp_file"
        else
            ((deleted_count++))
        fi
    done < "$data_file"
    
    if [ $deleted_count -gt 0 ]; then
        mv "$temp_file" "$data_file"
        echo "$deleted_count record(s) deleted successfully!"
    else
        rm "$temp_file"
        if [ $total_records -eq 0 ]; then
            echo "No records found in table '$table_name'."
        else
            echo "No matching records found with $search_value in column ${col_num}."
        fi
    fi
}

# Delete all data function
delete_all_data() {
    local db_name=$1
    local table_name=$2
    
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    read -p "Are you sure you want to delete all data from $table_name? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        > "$data_file"  # Empty the file
        echo "All data deleted from '$table_name'!"
    else
        echo "Operation cancelled."
    fi
}

# Update table function
update_table() {
    local db_name=$1
    read -p "Enter table name: " table_name
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    if [ ! -f "$meta_file" ]; then
        echo "Error: Table '$table_name' does not exist!"
        return
    fi
    
    # Read metadata
    source <(grep -v '^$' "$meta_file" | sed 's/:/=/')
    
    # Show available columns with types and primary key info
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
    
    # Get search column
    read -p "Enter column number to search for record: " search_col
    if [[ ! "$search_col" =~ ^[1-9][0-9]*$ ]] || [ "$search_col" -gt "$col_count" ]; then
        echo "Error: Invalid column number!"
        return
    fi
    
    read -p "Enter value to search: " search_value
    
    # Check if any records match the search
    matching_count=$(awk -F'|' -v col="$search_col" -v value="$search_value" '
    $col == value {count++} END {print count+0}' "$data_file")
    
    if [ "$matching_count" -eq 0 ]; then
        echo "Error: No records found with the specified search value!"
        return
    fi
    
    # Get update column
    read -p "Enter column number to update: " update_col
    if [[ ! "$update_col" =~ ^[1-9][0-9]*$ ]] || [ "$update_col" -gt "$col_count" ]; then
        echo "Error: Invalid column number!"
        return
    fi
    
    # Check if updating primary key
    col_primary_var="col${update_col}_primary"
    if [ "${!col_primary_var}" -eq 1 ]; then
        echo "WARNING: You are updating a PRIMARY KEY column!"
        read -p "Are you sure you want to update the primary key? (y/n): " confirm_pk
        if [[ ! "$confirm_pk" =~ ^[Yy]$ ]]; then
            echo "Update cancelled."
            return
        fi
    fi
    
    # Get new value with validation
    while true; do
        read -p "Enter new value: " new_value
        
        # Check for empty value (except for primary key which cannot be null)
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
        
        # Validate data type
        col_type_var="col${update_col}_type"
        col_type=${!col_type_var}
        
        if [ "$col_type" == "int" ] && [[ ! "$new_value" =~ ^-?[0-9]+$ ]]; then
            echo "Error: The column must contain integer values!"
            continue
        fi
        
        # Check primary key uniqueness if updating primary key
        if [ "${!col_primary_var}" -eq 1 ]; then
            # Check if new primary key already exists (excluding the current record being updated)
            pk_exists=0
            while IFS='|' read -ra fields; do
                if [ "${fields[$((update_col-1))]}" == "$new_value" ] && [ "${fields[$((search_col-1))]}" != "$search_value" ]; then
                    pk_exists=1
                    break
                fi
            done < "$data_file"
            
            if [ $pk_exists -eq 1 ]; then
                echo "Error: Primary key '$new_value' already exists in another record!"
                continue
            fi
        fi
        
        break
    done
    
    # Show what will be updated
    col_name_var="col${search_col}_name"
    update_col_name_var="col${update_col}_name"
    echo "Updating: ${!update_col_name_var} = '$new_value'"
    echo "Where: ${!col_name_var} = '$search_value'"
    echo "Affected records: $matching_count"
    
    read -p "Confirm update? (y/n): " final_confirm
    if [[ ! "$final_confirm" =~ ^[Yy]$ ]]; then
        echo "Update cancelled."
        return
    fi
    
    temp_file=$(mktemp)
    updated_count=0
    
    while IFS= read -r line; do
        IFS='|' read -ra fields <<< "$line"
        
        if [ "${fields[$((search_col-1))]}" == "$search_value" ]; then
            fields[$((update_col-1))]="$new_value"
            updated_line=$(IFS='|'; echo "${fields[*]}")
            echo "$updated_line" >> "$temp_file"
            ((updated_count++))
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$data_file"
    
    mv "$temp_file" "$data_file"
    echo "$updated_count record(s) updated successfully!"
}

mkdir -p "$DB_DIR"

echo "Starting Bash Shell Script DBMS..."
main_menu
