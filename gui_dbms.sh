#!/bin/bash

# Color Palette
COLOR_PRIMARY="#3498db"      # Vibrant Blue
COLOR_SECONDARY="#2ecc71"    # Emerald Green
COLOR_ACCENT="#9b59b6"       # Purple
COLOR_WARNING="#e67e22"      # Orange
COLOR_DANGER="#e74c3c"       # Red
COLOR_SUCCESS="#27ae60"      # Dark Green
COLOR_INFO="#2980b9"         # Blue
COLOR_BG="#ecf0f1"           # Light Gray Background
COLOR_CARD="#ffffff"         # White for cards
COLOR_TEXT="#2c3e50"         # Dark Text
COLOR_BORDER="#bdc3c7"       # Gray Border

# Font Settings
FONT_FAMILY="Sans"
FONT_TITLE="bold 14"
FONT_NORMAL="normal 11"
FONT_MONO="Monospace 10"

# Window Settings
WINDOW_WIDTH=600
WINDOW_HEIGHT=500

# Source original scripts
DB_DIR="databases"
mkdir -p "$DB_DIR"

# Import DBMS functions from the original script
source_dbms_functions() {
    # Database operations
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
    
    # Table operations
    create_table() {
        local db_name="$1"
        local table_name="$2"
        shift 2
        
        # Parse column definitions
        local col_count=$1
        local col_names=()
        local col_types=()
        local is_primary=()
        
        # Skip col_count
        shift
        
        # Read column names
        for ((i=0; i<col_count; i++)); do
            col_names[$i]="$1"
            shift
        done
        
        # Read column types
        for ((i=0; i<col_count; i++)); do
            col_types[$i]="$1"
            shift
        done
        
        # Read primary key flags
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
    
    insert_into_table_sql() {
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
        
        # Validate values
        for ((i=1; i<=col_count; i++)); do
            col_type=$(grep "^col${i}_type:" "$meta_file" | cut -d: -f2)
            is_primary=$(grep "^col${i}_primary:" "$meta_file" | cut -d: -f2)
            value="${values[$((i-1))]}"
            
            if [ "$is_primary" -eq 1 ]; then
                if [ -z "$value" ]; then
                    echo "Error: Primary key cannot be empty!"
                    return 1
                fi
                
                # Check uniqueness
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
        
        row_data=$(IFS='|'; echo "${values[*]}")
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
        
        # Read metadata
        source <(grep -v '^$' "$meta_file" | sed 's/:/=/')
        
        # Create header
        header=""
        for ((i=1; i<=col_count; i++)); do
            col_name_var="col${i}_name"
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
    
    select_where_sql() {
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
        
        header=""
        for ((i=1; i<=col_count; i++)); do
            col_name_var="col${i}_name"
            header+="${!col_name_var}"
            if [ $i -lt $col_count ]; then
                header+="|"
            fi
        done
        
        echo "$header"
        
        if [ -f "$data_file" ] && [ -s "$data_file" ]; then
            local match_count=0
            while IFS='|' read -ra fields; do
                if [ "${fields[$((where_col_index-1))]}" = "$where_value" ]; then
                    echo "$(IFS='|'; echo "${fields[*]}")"
                    ((match_count++))
                fi
            done < "$data_file"
            
            if [ $match_count -eq 0 ]; then
                echo "No matching records found!"
            fi
            echo "Matching records: $match_count"
        else
            echo "No data found!"
        fi
        return 0
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
            return 1
        fi
        
        # Get column indices
        local update_col_index=0
        local where_col_index=0
        
        for i in {1..100}; do
            col_line=$(grep "^col${i}_name:" "$meta_file" 2>/dev/null)
            if [ -z "$col_line" ]; then
                break
            fi
            
            col_name=$(echo "$col_line" | cut -d: -f2)
            if [ "$col_name" = "$update_col" ]; then
                update_col_index=$i
            fi
            if [ "$col_name" = "$where_col" ]; then
                where_col_index=$i
            fi
        done
        
        if [ $update_col_index -eq 0 ]; then
            echo "Error: Column '$update_col' not found!"
            return 1
        fi
        
        if [ $where_col_index -eq 0 ]; then
            echo "Error: Column '$where_col' not found!"
            return 1
        fi
        
        # Check type
        local col_type=$(grep "^col${update_col_index}_type:" "$meta_file" | cut -d: -f2)
        if [ "$col_type" == "int" ] && [[ ! "$new_value" =~ ^-?[0-9]+$ ]]; then
            echo "Error: Column '$update_col' must be integer, got '$new_value'"
            return 1
        fi
        
        # Check primary key uniqueness
        local is_primary=$(grep "^col${update_col_index}_primary:" "$meta_file" | cut -d: -f2)
        if [ "$is_primary" -eq 1 ]; then
            # Check if new value exists in other records
            if [ -f "$data_file" ] && [ -s "$data_file" ]; then
                while IFS= read -r line; do
                    IFS='|' read -ra fields <<< "$line"
                    if [ "${fields[$((where_col_index-1))]}" != "$where_value" ] && [ "${fields[$((update_col_index-1))]}" == "$new_value" ]; then
                        echo "Error: Primary key '$new_value' already exists in another record!"
                        return 1
                    fi
                done < "$data_file"
            fi
        fi
        
        # Perform update
        local temp_file=$(mktemp)
        local updated_count=0
        
        while IFS= read -r line; do
            IFS='|' read -ra fields <<< "$line"
            
            if [ "${fields[$((where_col_index-1))]}" = "$where_value" ]; then
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
        return 0
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
            return 1
        fi
        
        # Get column index
        local where_col_index=0
        for i in {1..100}; do
            col_line=$(grep "^col${i}_name:" "$meta_file" 2>/dev/null)
            if [ -z "$col_line" ]; then
                break
            fi
            
            col_name=$(echo "$col_line" | cut -d: -f2)
            if [ "$col_name" = "$where_col" ]; then
                where_col_index=$i
                break
            fi
        done
        
        if [ $where_col_index -eq 0 ]; then
            echo "Error: Column '$where_col' not found!"
            return 1
        fi
        
        local temp_file=$(mktemp)
        local deleted_count=0
        
        while IFS= read -r line; do
            IFS='|' read -ra fields <<< "$line"
            
            if [ "${fields[$((where_col_index-1))]}" = "$where_value" ]; then
                ((deleted_count++))
            else
                echo "$line" >> "$temp_file"
            fi
        done < "$data_file"
        
        mv "$temp_file" "$data_file"
        echo "$deleted_count row(s) deleted successfully!"
        return 0
    }
    
    # Export functions
    export -f create_database
    export -f list_databases
    export -f drop_database
    export -f create_table
    export -f insert_into_table_sql
    export -f select_all
    export -f select_where_sql
    export -f update_table_sql
    export -f delete_from_table_sql
}

# Initialize DBMS functions
source_dbms_functions

# Source SQL parser if available
if [ -f "sql_parser.sh" ]; then
    # Patch the SQL parser to use our functions
    source "sql_parser.sh" 2>/dev/null || true
    
    # Override problematic functions
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
    
    SQL_PARSER_AVAILABLE=1
else
    SQL_PARSER_AVAILABLE=0
    echo "Warning: SQL parser not found. SQL mode disabled." > /dev/null
fi

# Global variables
CURRENT_DB=""
SQL_CURRENT_DB=""

# ============================================
# UTILITY FUNCTIONS
# ============================================

show_dialog() {
    zenity --window-icon="dialog-information" \
           --width=$WINDOW_WIDTH \
           --height=$WINDOW_HEIGHT \
           "$@"
}

show_info() {
    show_dialog --info \
        --title="💡 Information" \
        --text="$1" \
        --icon-name="dialog-information"
}

show_success() {
    show_dialog --info \
        --title="✅ Success" \
        --text="$1" \
        --icon-name="emblem-default"
}

show_error() {
    show_dialog --error \
        --title="❌ Error" \
        --text="$1" \
        --icon-name="dialog-error"
}

show_warning() {
    show_dialog --warning \
        --title="⚠️ Warning" \
        --text="$1" \
        --icon-name="dialog-warning"
}

confirm_action() {
    local message="$1"
    local title="${2:-Confirmation}"
    
    zenity --question \
        --title="$title" \
        --text="$message" \
        --width=400 \
        --height=150 \
        --ok-label="Yes" \
        --cancel-label="No"
    return $?
}

show_loading() {
    echo "$1" | zenity --progress \
        --title="⏳ Processing" \
        --text="Please wait..." \
        --pulsate \
        --auto-close \
        --no-cancel \
        --width=300
}

show_form() {
    zenity --forms \
        --title="$1" \
        --text="$2" \
        --width=500 \
        --add-entry="$3" \
        --separator="|" \
        --window-icon="dialog-information"
}

show_list() {
    zenity --list \
        --title="$1" \
        --text="$2" \
        --column="$3" \
        --width=600 \
        --height=400 \
        --window-icon="view-list" \
        "$@"
}

show_table_data() {
    local title="$1"
    local file="$2"
    
    if [ -s "$file" ]; then
        zenity --text-info \
            --title="$title" \
            --filename="$file" \
            --width=800 \
            --height=600 \
            --font="$FONT_MONO" \
            --wrap
    else
        show_info "No data found!"
    fi
}

create_database_gui() {
    local db_name=$(zenity --entry \
        --title="📁 Create Database" \
        --text="Enter a name for the new database:" \
        --entry-text="" \
        --width=400)
    
    if [ -z "$db_name" ]; then
        return
    fi
    
    # Validate name
    if [[ ! "$db_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        show_error "Invalid database name!\n\nRules:\n• Must start with letter or underscore\n• Can only contain letters, numbers, and underscores"
        return
    fi
    
    local result
    result=$(create_database "$db_name" 2>&1)
    
    if [ $? -eq 0 ]; then
        show_success "$result"
    else
        show_error "$result"
    fi
}

list_databases_gui() {
    local databases=()
    
    if [ -d "$DB_DIR" ] && [ "$(ls -A "$DB_DIR" 2>/dev/null)" ]; then
        while IFS= read -r db; do
            databases+=("$db")
        done < <(list_databases)
    else
        show_info "No databases found!\n\nCreate a new database to get started."
        return
    fi
    
    local selected=$(zenity --list \
        --title="📚 Available Databases" \
        --text="Select a database to connect:" \
        --column="Database Name" \
        "${databases[@]}" \
        --height=300 \
        --ok-label="Connect" \
        --cancel-label="Back")
    
    if [ -n "$selected" ]; then
        CURRENT_DB="$selected"
        SQL_CURRENT_DB="$selected"
        show_success "Connected to database: $selected 🔗"
        table_menu_gui "$selected"
    fi
}

connect_database_gui() {
    list_databases_gui
}

drop_database_gui() {
    local databases=()
    
    if [ -d "$DB_DIR" ] && [ "$(ls -A "$DB_DIR" 2>/dev/null)" ]; then
        while IFS= read -r db; do
            databases+=("$db")
        done < <(list_databases)
    else
        show_error "No databases available to drop!"
        return
    fi
    
    local selected=$(zenity --list \
        --title="🗑️ Drop Database" \
        --text="Select database to delete:" \
        --column="Database Name" \
        "${databases[@]}" \
        --height=300)
    
    if [ -z "$selected" ]; then
        return
    fi
    
    if confirm_action "Are you sure you want to delete database '$selected'?\n\n⚠️ This action cannot be undone!" "Confirm Deletion"; then
        local result
        result=$(drop_database "$selected" 2>&1)
        
        if [ $? -eq 0 ]; then
            if [ "$CURRENT_DB" == "$selected" ]; then
                CURRENT_DB=""
                SQL_CURRENT_DB=""
            fi
            show_success "$result"
        else
            show_error "$result"
        fi
    fi
}

table_menu_gui() {
    local db_name="$1"
    
    while true; do
        local choice=$(zenity --list \
            --title="📊 Database: $db_name" \
            --text="Select table operation:" \
            --column="Operation" \
            --column="Description" \
            "📝 Create Table" "Create a new table" \
            "📋 List Tables" "Show all tables in database" \
            "🗑️ Drop Table" "Delete an existing table" \
            "➕ Insert Record" "Add new data to table" \
            "🔍 Select Data" "View table data" \
            "✏️ Update Record" "Modify existing data" \
            "❌ Delete Record" "Remove data from table" \
            "🔙 Back" "Return to main menu" \
            --width=700 \
            --height=450 \
            --ok-label="Select" \
            --cancel-label="Back")
        
        case "$choice" in
            "📝 Create Table")
                create_table_gui "$db_name"
                ;;
            "📋 List Tables")
                list_tables_gui "$db_name"
                ;;
            "🗑️ Drop Table")
                drop_table_gui "$db_name"
                ;;
            "➕ Insert Record")
                insert_into_table_gui "$db_name"
                ;;
            "🔍 Select Data")
                select_from_table_gui "$db_name"
                ;;
            "✏️ Update Record")
                update_table_gui "$db_name"
                ;;
            "❌ Delete Record")
                delete_from_table_gui "$db_name"
                ;;
            "🔙 Back"|"")
                return
                ;;
        esac
    done
}

create_table_gui() {
    local db_name="$1"
    
    # Get table name
    local table_name=$(zenity --entry \
        --title="📝 Create New Table" \
        --text="Enter table name:" \
        --width=400)
    
    if [ -z "$table_name" ]; then
        return
    fi
    
    # Validate table name
    if [[ ! "$table_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        show_error "Invalid table name!\n\nMust start with letter/underscore and contain only alphanumeric characters."
        return
    fi
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    if [ -f "$meta_file" ]; then
        show_error "Table '$table_name' already exists!"
        return
    fi
    
    # Get number of columns
    local col_count=$(zenity --scale \
        --title="Table Columns" \
        --text="How many columns should the table have?" \
        --min-value=1 \
        --max-value=15 \
        --value=3 \
        --step=1 \
        --width=500)
    
    if [ -z "$col_count" ]; then
        return
    fi
    
    # Collect column information
    declare -a col_names col_types is_primary
    local primary_set=0
    
    for ((i=1; i<=col_count; i++)); do
        local col_info=$(zenity --forms \
            --title="Column $i Details" \
            --text="Enter information for column $i:" \
            --add-entry="Column Name:" \
            --add-combo="Data Type:" \
            --combo-values="string|int" \
            --add-combo="Primary Key?" \
            --combo-values="No|Yes" \
            --separator="|" \
            --width=550)
        
        if [ -z "$col_info" ]; then
            show_warning "Table creation cancelled!"
            return
        fi
        
        IFS='|' read -r col_name col_type primary_flag <<< "$col_info"
        
        # Validate column name
        if [[ ! "$col_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            show_error "Invalid column name for column $i!\n\nMust start with letter/underscore."
            ((i--))
            continue
        fi
        
        # Check for duplicates
        if [[ " ${col_names[@]} " =~ " ${col_name} " ]]; then
            show_error "Column name '$col_name' already used!"
            ((i--))
            continue
        fi
        
        col_names[$i]="$col_name"
        col_types[$i]="$col_type"
        
        if [ "$primary_flag" = "Yes" ]; then
            if [ $primary_set -eq 0 ]; then
                is_primary[$i]=1
                primary_set=1
                show_info "✓ '$col_name' set as PRIMARY KEY"
            else
                show_error "Only one primary key allowed!\n\n'$col_name' will not be primary key."
                is_primary[$i]=0
            fi
        else
            is_primary[$i]=0
        fi
    done
    
    # Ensure we have a primary key
    if [ $primary_set -eq 0 ]; then
        local pk_options=""
        for ((i=1; i<=col_count; i++)); do
            pk_options+="FALSE ${col_names[$i]} "
        done
        
        local pk_choice=$(zenity --list \
            --title="Select Primary Key" \
            --text="No primary key selected. Choose a column as primary key:" \
            --radiolist \
            --column="Select" \
            --column="Column" \
            $pk_options \
            --width=400 \
            --height=300)
        
        if [ -n "$pk_choice" ]; then
            for ((i=1; i<=col_count; i++)); do
                if [ "${col_names[$i]}" = "$pk_choice" ]; then
                    is_primary[$i]=1
                    primary_set=1
                    break
                fi
            done
        fi
    fi
    
    # Create table using our function
    local result
    result=$(create_table "$db_name" "$table_name" "$col_count" \
             "${col_names[@]:1}" "${col_types[@]:1}" "${is_primary[@]:1}" 2>&1)
    
    if [ $? -eq 0 ]; then
        # Show summary
        local summary="Table '$table_name' created successfully! ✅\n\n"
        summary+="Columns:\n"
        for ((i=1; i<=col_count; i++)); do
            local pk_mark=""
            [ ${is_primary[$i]} -eq 1 ] && pk_mark=" (PK)"
            summary+="  ${col_names[$i]} - ${col_types[$i]}$pk_mark\n"
        done
        show_success "$summary"
    else
        show_error "$result"
    fi
}

list_tables_gui() {
    local db_name="$1"
    local tables=()
    
    if ls "$DB_DIR/$db_name"/*_meta 2>/dev/null 1>&2; then
        while IFS= read -r meta_file; do
            local table_name=$(basename "$meta_file" _meta)
            tables+=("$table_name")
        done < <(ls "$DB_DIR/$db_name"/*_meta)
    else
        show_info "No tables found in database '$db_name'"
        return
    fi
    
    local selected=$(zenity --list \
        --title="📋 Tables in $db_name" \
        --text="Tables available in this database:" \
        --column="Table Name" \
        "${tables[@]}" \
        --height=300 \
        --ok-label="Open" \
        --cancel-label="Back")
    
    if [ -n "$selected" ]; then
        show_table_info "$db_name" "$selected"
    fi
}

show_table_info() {
    local db_name="$1"
    local table_name="$2"
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    
    if [ ! -f "$meta_file" ]; then
        show_error "Table metadata not found!"
        return
    fi
    
    # Read metadata
    source <(grep -v '^$' "$meta_file" | sed 's/:/=/')
    
    local info="📊 Table: $table_name\n"
    info+="Columns: $col_count\n\n"
    info+="Column Details:\n"
    
    for ((i=1; i<=col_count; i++)); do
        local col_name_var="col${i}_name"
        local col_type_var="col${i}_type"
        local col_primary_var="col${i}_primary"
        
        local pk_mark=""
        [ ${!col_primary_var} -eq 1 ] && pk_mark=" 🔑 PRIMARY KEY"
        
        info+="  ${!col_name_var} (${!col_type_var})$pk_mark\n"
    done
    
    # Count records
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    local record_count=0
    [ -f "$data_file" ] && record_count=$(wc -l < "$data_file")
    info+="\n📈 Records: $record_count"
    
    zenity --info \
        --title="Table Information" \
        --text="$info" \
        --width=500 \
        --height=350
}

drop_table_gui() {
    local db_name="$1"
    local tables=()
    
    if ls "$DB_DIR/$db_name"/*_meta 2>/dev/null 1>&2; then
        while IFS= read -r meta_file; do
            local table_name=$(basename "$meta_file" _meta)
            tables+=("$table_name")
        done < <(ls "$DB_DIR/$db_name"/*_meta)
    else
        show_error "No tables found to drop!"
        return
    fi
    
    local selected=$(zenity --list \
        --title="🗑️ Drop Table" \
        --text="Select table to delete:" \
        --column="Table Name" \
        "${tables[@]}" \
        --height=300)
    
    if [ -z "$selected" ]; then
        return
    fi
    
    if confirm_action "Delete table '$selected'?\n\nAll data will be permanently lost!" "Confirm Delete"; then
        rm -f "$DB_DIR/$db_name/${selected}_meta" "$DB_DIR/$db_name/${selected}_data"
        show_success "Table '$selected' has been deleted!"
    fi
}

insert_into_table_gui() {
    local db_name="$1"
    
    # Get list of tables
    local tables=()
    if ls "$DB_DIR/$db_name"/*_meta 2>/dev/null 1>&2; then
        while IFS= read -r meta_file; do
            local table_name=$(basename "$meta_file" _meta)
            tables+=("$table_name")
        done < <(ls "$DB_DIR/$db_name"/*_meta)
    else
        show_error "No tables available!"
        return
    fi
    
    local table_name=$(zenity --list \
        --title="➕ Insert Record" \
        --text="Select table to insert into:" \
        --column="Table Name" \
        "${tables[@]}" \
        --height=300)
    
    if [ -z "$table_name" ]; then
        return
    fi
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    
    if [ ! -f "$meta_file" ]; then
        show_error "Table '$table_name' not found!"
        return
    fi
    
    # Read metadata
    source <(grep -v '^$' "$meta_file" | sed 's/:/=/')
    
    # Build form dynamically
    local form_cmd="zenity --forms --title='Insert into $table_name' --text='Enter values (leave empty for NULL):' --separator='|' --width=600"
    
    for ((i=1; i<=col_count; i++)); do
        local col_name_var="col${i}_name"
        local col_type_var="col${i}_type"
        local col_primary_var="col${i}_primary"
        
        local col_name=${!col_name_var}
        local col_type=${!col_type_var}
        local is_primary=${!col_primary_var}
        
        local required=""
        if [ $is_primary -eq 1 ]; then
            required=" (Primary Key - Required)"
        fi
        
        form_cmd+=" --add-entry='$col_name: $col_type$required'"
    done
    
    local values=$(eval "$form_cmd")
    
    if [ -z "$values" ]; then
        return
    fi
    
    IFS='|' read -ra value_array <<< "$values"
    
    # Insert using our function
    local result
    result=$(insert_into_table_sql "$db_name" "$table_name" "${value_array[@]}" 2>&1)
    
    if [ $? -eq 0 ]; then
        show_success "$result\n\nTable: $table_name"
    else
        show_error "$result"
    fi
}

select_from_table_gui() {
    local db_name="$1"
    
    # Get table list
    local tables=()
    if ls "$DB_DIR/$db_name"/*_meta 2>/dev/null 1>&2; then
        while IFS= read -r meta_file; do
            local table_name=$(basename "$meta_file" _meta)
            tables+=("$table_name")
        done < <(ls "$DB_DIR/$db_name"/*_meta)
    else
        show_error "No tables available!"
        return
    fi
    
    local table_name=$(zenity --list \
        --title="🔍 Select Data" \
        --text="Select table to query:" \
        --column="Table Name" \
        "${tables[@]}" \
        --height=300)
    
    if [ -z "$table_name" ]; then
        return
    fi
    
    local choice=$(zenity --list \
        --title="Query Type" \
        --text="How would you like to select data?" \
        --column="Option" \
        "Select All Data" \
        "Select Specific Columns" \
        "Select with Condition" \
        "Select Specific Columns with Condition" \
        --height=250)
    
    case "$choice" in
        "Select All Data")
            select_all_gui "$db_name" "$table_name"
            ;;
        "Select Specific Columns")
            select_specific_columns_gui "$db_name" "$table_name"
            ;;
        "Select with Condition")
            select_where_gui "$db_name" "$table_name"
            ;;
        "Select Specific Columns with Condition")
            select_specific_columns_with_condition_gui "$db_name" "$table_name"
            ;;
    esac
}

select_specific_columns_gui() {
    local db_name="$1"
    local table_name="$2"
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    if [ ! -f "$meta_file" ]; then
        show_error "Table metadata not found!"
        return
    fi
    
    # Read metadata
    source <(grep -v '^$' "$meta_file" | sed 's/:/=/')
    
    # Build column options for selection
    declare -a col_options_array
    for ((i=1; i<=col_count; i++)); do
        col_name_var="col${i}_name"
        col_type_var="col${i}_type"
        col_options_array+=("FALSE")
        col_options_array+=("${!col_name_var} (${!col_type_var})")
    done
    
    # Let user select multiple columns
    local selected_cols=$(zenity --list \
        --title="Select Columns" \
        --text="Choose columns to display (Ctrl+Click for multiple):" \
        --checklist \
        --column="Select" \
        --column="Column" \
        "${col_options_array[@]}" \
        --separator="," \
        --multiple \
        --width=500 \
        --height=300)
    
    if [ -z "$selected_cols" ]; then
        return
    fi
    
    # Convert selected columns to indices
    declare -a col_indices
    IFS=',' read -ra selected_array <<< "$selected_cols"
    
    # Extract just column names (remove type info)
    declare -a col_names_selected
    for selected_item in "${selected_array[@]}"; do
        col_name=$(echo "$selected_item" | awk '{print $1}')
        col_names_selected+=("$col_name")
    done
    
    # Get indices for selected columns
    for col_name in "${col_names_selected[@]}"; do
        for ((i=1; i<=col_count; i++)); do
            col_name_var="col${i}_name"
            if [ "${!col_name_var}" = "$col_name" ]; then
                col_indices+=($i)
                break
            fi
        done
    done
    
    # Create header
    local header=""
    for idx in "${col_indices[@]}"; do
        col_name_var="col${idx}_name"
        header+="${!col_name_var}"
        [ $idx -ne ${col_indices[-1]} ] && header+="|"
    done
    
    # Create display file
    local display_file=$(mktemp)
    echo "$header" > "$display_file"
    
    if [ -f "$data_file" ] && [ -s "$data_file" ]; then
        # Extract selected columns using cut
        cut_fields=$(IFS=','; echo "${col_indices[*]}")
        cut -d'|' -f"$cut_fields" "$data_file" >> "$display_file"
    fi
    
    local record_count=0
    [ -f "$data_file" ] && record_count=$(wc -l < "$data_file")
    
    # Add summary
    echo -e "\n=== Summary ===" >> "$display_file"
    echo "Showing columns: $(IFS=', '; echo "${col_names_selected[*]}")" >> "$display_file"
    echo "Total records: $record_count" >> "$display_file"
    
    # Format and display
    if command -v column &>/dev/null && [ $record_count -gt 0 ]; then
        local formatted_file=$(mktemp)
        column -t -s '|' "$display_file" > "$formatted_file" 2>/dev/null || cp "$display_file" "$formatted_file"
        mv "$formatted_file" "$display_file"
    fi
    
    zenity --text-info \
        --title="📊 $table_name - Selected Columns" \
        --filename="$display_file" \
        --width=900 \
        --height=600 \
        --font="$FONT_MONO"
    
    rm -f "$display_file"
}

select_specific_columns_with_condition_gui() {
    local db_name="$1"
    local table_name="$2"
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    if [ ! -f "$meta_file" ]; then
        show_error "Table metadata not found!"
        return
    fi
    
    # Read metadata
    source <(grep -v '^$' "$meta_file" | sed 's/:/=/')
    
    # STEP 1: Select column for WHERE condition
    declare -a where_col_options
    for ((i=1; i<=col_count; i++)); do
        col_name_var="col${i}_name"
        col_type_var="col${i}_type"
        where_col_options+=("FALSE")
        where_col_options+=("${!col_name_var} (${!col_type_var})")
    done
    
    local where_col=$(zenity --list \
        --title="Select Filter Column" \
        --text="Choose column for WHERE condition:" \
        --radiolist \
        --column="Select" \
        --column="Column" \
        "${where_col_options[@]}" \
        --width=500 \
        --height=300)
    
    if [ -z "$where_col" ]; then
        return
    fi
    
    # Extract column name
    where_col=$(echo "$where_col" | awk '{print $1}')
    
    # Get column index for WHERE
    local where_col_idx=0
    for ((i=1; i<=col_count; i++)); do
        col_name_var="col${i}_name"
        if [ "${!col_name_var}" = "$where_col" ]; then
            where_col_idx=$i
            break
        fi
    done
    
    # STEP 2: Get value to match
    local where_value=$(zenity --entry \
        --title="Filter Value" \
        --text="Enter value for column '$where_col':" \
        --width=400)
    
    if [ -z "$where_value" ]; then
        return
    fi
    
    # STEP 3: Select columns to display
    declare -a display_col_options
    for ((i=1; i<=col_count; i++)); do
        col_name_var="col${i}_name"
        col_type_var="col${i}_type"
        display_col_options+=("FALSE")
        display_col_options+=("${!col_name_var} (${!col_type_var})")
    done
    
    local display_cols=$(zenity --list \
        --title="Select Display Columns" \
        --text="Choose columns to show in results:" \
        --checklist \
        --column="Select" \
        --column="Column" \
        "${display_col_options[@]}" \
        --separator="," \
        --multiple \
        --width=500 \
        --height=300)
    
    if [ -z "$display_cols" ]; then
        return
    fi
    
    # Convert display columns to indices
    declare -a display_indices
    declare -a display_names
    IFS=',' read -ra selected_array <<< "$display_cols"
    
    # Extract column names
    for selected_item in "${selected_array[@]}"; do
        col_name=$(echo "$selected_item" | awk '{print $1}')
        display_names+=("$col_name")
    done
    
    # Get indices for display columns
    for col_name in "${display_names[@]}"; do
        for ((i=1; i<=col_count; i++)); do
            col_name_var="col${i}_name"
            if [ "${!col_name_var}" = "$col_name" ]; then
                display_indices+=($i)
                break
            fi
        done
    done
    
    # Create header
    local header=""
    for idx in "${display_indices[@]}"; do
        col_name_var="col${idx}_name"
        header+="${!col_name_var}"
        [ $idx -ne ${display_indices[-1]} ] && header+="|"
    done
    
    # Create display file
    local display_file=$(mktemp)
    echo "$header" > "$display_file"
    
    local match_count=0
    if [ -f "$data_file" ] && [ -s "$data_file" ]; then
        while IFS='|' read -ra fields; do
            if [ "${fields[$((where_col_idx-1))]}" = "$where_value" ]; then
                local row=""
                for idx in "${display_indices[@]}"; do
                    row+="${fields[$((idx-1))]}"
                    [ $idx -ne ${display_indices[-1]} ] && row+="|"
                done
                echo "$row" >> "$display_file"
                ((match_count++))
            fi
        done < "$data_file"
    fi
    
    # Add summary
    echo -e "\n=== Summary ===" >> "$display_file"
    echo "Filter: $where_col = '$where_value'" >> "$display_file"
    echo "Showing columns: $(IFS=', '; echo "${display_names[*]}")" >> "$display_file"
    echo "Matching records: $match_count" >> "$display_file"
    
    # Format and display
    if command -v column &>/dev/null && [ $match_count -gt 0 ]; then
        local formatted_file=$(mktemp)
        column -t -s '|' "$display_file" > "$formatted_file" 2>/dev/null || cp "$display_file" "$formatted_file"
        mv "$formatted_file" "$display_file"
    fi
    
    zenity --text-info \
        --title="🔍 $table_name - Advanced Query" \
        --filename="$display_file" \
        --width=900 \
        --height=600 \
        --font="$FONT_MONO"
    
    rm -f "$display_file"
}

select_where_gui() {
    local db_name="$1"
    local table_name="$2"
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    
    if [ ! -f "$meta_file" ]; then
        show_error "Table metadata not found!"
        return
    fi
    
    # Read metadata to get column names
    source <(grep -v '^$' "$meta_file" | sed 's/:/=/')
    
    # Build column options array
    declare -a col_options_array
    for ((i=1; i<=col_count; i++)); do
        col_name_var="col${i}_name"
        col_type_var="col${i}_type"
        col_options_array+=("FALSE")
        col_options_array+=("${!col_name_var} (${!col_type_var})")
    done
    
    local where_col=$(zenity --list \
        --title="Select Column for Condition" \
        --text="Choose column to filter by:" \
        --radiolist \
        --column="Select" \
        --column="Column" \
        "${col_options_array[@]}" \
        --width=500 \
        --height=300)
    
    if [ -z "$where_col" ]; then
        return
    fi
    
    # Extract just the column name (remove type)
    where_col=$(echo "$where_col" | awk '{print $1}')
    
    # Get column index
    local where_col_idx=0
    for ((i=1; i<=col_count; i++)); do
        col_name_var="col${i}_name"
        if [ "${!col_name_var}" = "$where_col" ]; then
            where_col_idx=$i
            break
        fi
    done
    
    # Get value to match
    local where_value=$(zenity --entry \
        --title="Enter Condition Value" \
        --text="Enter value to match for column '$where_col':" \
        --width=400)
    
    if [ -z "$where_value" ]; then
        return
    fi
    
    # Execute query using our function
    local result
    result=$(select_where_sql "$db_name" "$table_name" "$where_col_idx" "$where_value" 2>&1)
    
    if [ $? -eq 0 ]; then
        # Create display file
        local display_file=$(mktemp)
        echo "$result" > "$display_file"
        
        # Format with column if available
        if command -v column &>/dev/null; then
            local formatted_file=$(mktemp)
            column -t -s '|' "$display_file" > "$formatted_file" 2>/dev/null || cp "$display_file" "$formatted_file"
            mv "$formatted_file" "$display_file"
        fi
        
        zenity --text-info \
            --title="🔍 $table_name - Filtered Results" \
            --filename="$display_file" \
            --width=900 \
            --height=600 \
            --font="$FONT_MONO"
        
        rm -f "$display_file"
    else
        show_error "$result"
    fi
}

select_all_gui() {
    local db_name="$1"
    local table_name="$2"
    
    local result
    result=$(select_all "$db_name" "$table_name" 2>&1)
    
    if [ $? -eq 0 ]; then
        # Create display file
        local display_file=$(mktemp)
        echo "$result" > "$display_file"
        
        # Format with column if available
        if command -v column &>/dev/null; then
            local formatted_file=$(mktemp)
            column -t -s '|' "$display_file" > "$formatted_file" 2>/dev/null || cp "$display_file" "$formatted_file"
            mv "$formatted_file" "$display_file"
        fi
        
        zenity --text-info \
            --title="📊 $table_name - All Data" \
            --filename="$display_file" \
            --width=900 \
            --height=600 \
            --font="$FONT_MONO"
        
        rm -f "$display_file"
    else
        show_error "$result"
    fi
}


delete_from_table_gui() {
    local db_name="$1"
    
    # Get table list
    local tables=()
    if ls "$DB_DIR/$db_name"/*_meta 2>/dev/null 1>&2; then
        while IFS= read -r meta_file; do
            local table_name=$(basename "$meta_file" _meta)
            tables+=("$table_name")
        done < <(ls "$DB_DIR/$db_name"/*_meta)
    else
        show_error "No tables available!"
        return
    fi
    
    local table_name=$(zenity --list \
        --title="❌ Delete Data" \
        --text="Select table:" \
        --column="Table Name" \
        "${tables[@]}" \
        --height=300)
    
    if [ -z "$table_name" ]; then
        return
    fi
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    
    if [ ! -f "$meta_file" ]; then
        show_error "Table metadata not found!"
        return
    fi
    
    # Read metadata
    source <(grep -v '^$' "$meta_file" | sed 's/:/=/')
    
    # Select column
    local col_options=""
    for ((i=1; i<=col_count; i++)); do
        col_name_var="col${i}_name"
        col_options+="FALSE ${!col_name_var} "
    done
    
    local where_col=$(zenity --list \
        --title="Select Column" \
        --text="Choose column for deletion condition:" \
        --radiolist \
        --column="Select" \
        --column="Column" \
        $col_options \
        --width=500 \
        --height=300)
    
    if [ -z "$where_col" ]; then
        return
    fi
    
    # Get value
    local where_value=$(zenity --entry \
        --title="Enter Value" \
        --text="Delete records where '$where_col' equals:" \
        --width=400)
    
    if [ -z "$where_value" ]; then
        return
    fi
    
    # Count matching records
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    local match_count=0
    if [ -f "$data_file" ] && [ -s "$data_file" ]; then
        # Get column index
        local where_col_idx=0
        for ((i=1; i<=col_count; i++)); do
            col_name_var="col${i}_name"
            if [ "${!col_name_var}" = "$where_col" ]; then
                where_col_idx=$i
                break
            fi
        done
        
        match_count=$(awk -F'|' -v col="$where_col_idx" -v value="$where_value" '
            $col == value {count++} 
            END {print count}
        ' "$data_file")
    fi
    
    if [ "$match_count" -eq 0 ]; then
        show_info "No records found with $where_col = '$where_value'"
        return
    fi
    
    # Confirm deletion
    if ! confirm_action "Delete $match_count record(s) where $where_col = '$where_value'?" "Confirm Deletion"; then
        return
    fi
    
    # Perform deletion using function
    local result
    result=$(delete_from_table_sql "$db_name" "$table_name" "$where_col" "$where_value" 2>&1)
    
    if [ $? -eq 0 ]; then
        show_success "$result"
    else
        show_error "$result"
    fi
}

delete_all_data_gui() {
    local db_name="$1"
    local table_name="$2"
    
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    
    # Count current records
    local record_count=0
    [ -f "$data_file" ] && record_count=$(wc -l < "$data_file")
    
    if [ "$record_count" -eq 0 ]; then
        show_info "Table is already empty!"
        return
    fi
    
    if confirm_action "Delete ALL $record_count records from '$table_name'?\n\n⚠️ This action cannot be undone!" "Dangerous Operation"; then
        > "$data_file"  # Empty the file
        show_success "✅ All $record_count records deleted from '$table_name'!"
    fi
}

update_table_gui() {
    local db_name="$1"
    
    # Get table list
    local tables=()
    if ls "$DB_DIR/$db_name"/*_meta 2>/dev/null 1>&2; then
        while IFS= read -r meta_file; do
            local table_name=$(basename "$meta_file" _meta)
            tables+=("$table_name")
        done < <(ls "$DB_DIR/$db_name"/*_meta)
    else
        show_error "No tables available!"
        return
    fi
    
    local table_name=$(zenity --list \
        --title="✏️ Update Data" \
        --text="Select table to update:" \
        --column="Table Name" \
        "${tables[@]}" \
        --height=300)
    
    if [ -z "$table_name" ]; then
        return
    fi
    
    local meta_file="$DB_DIR/$db_name/${table_name}_meta"
    
    if [ ! -f "$meta_file" ]; then
        show_error "Table metadata not found!"
        return
    fi
    
    # Read metadata
    source <(grep -v '^$' "$meta_file" | sed 's/:/=/')
    
    # Build search column options array
    declare -a search_col_options
    for ((i=1; i<=col_count; i++)); do
        col_name_var="col${i}_name"
        col_type_var="col${i}_type"
        col_primary_var="col${i}_primary"
        
        local pk_mark=""
        [ ${!col_primary_var} -eq 1 ] && pk_mark=" (PK)"
        
        search_col_options+=("FALSE")
        search_col_options+=("${!col_name_var} - ${!col_type_var}$pk_mark")
    done
    
    local search_col=$(zenity --list \
        --title="Select Search Column" \
        --text="Choose column to identify records to update:" \
        --radiolist \
        --column="Select" \
        --column="Column" \
        "${search_col_options[@]}" \
        --width=600 \
        --height=350)
    
    if [ -z "$search_col" ]; then
        return
    fi
    
    # Extract column name (remove type and PK marker)
    search_col=$(echo "$search_col" | awk '{print $1}')
    
    # Get search value
    local search_value=$(zenity --entry \
        --title="Search Value" \
        --text="Update records where '$search_col' equals:" \
        --width=400)
    
    if [ -z "$search_value" ]; then
        return
    fi
    
    # Build update column options array
    declare -a update_col_options
    for ((i=1; i<=col_count; i++)); do
        col_name_var="col${i}_name"
        col_type_var="col${i}_type"
        col_primary_var="col${i}_primary"
        
        local pk_mark=""
        [ ${!col_primary_var} -eq 1 ] && pk_mark=" (PK)"
        
        update_col_options+=("FALSE")
        update_col_options+=("${!col_name_var} - ${!col_type_var}$pk_mark")
    done
    
    local update_col=$(zenity --list \
        --title="Select Column to Update" \
        --text="Choose column to modify:" \
        --radiolist \
        --column="Select" \
        --column="Column" \
        "${update_col_options[@]}" \
        --width=600 \
        --height=350)
    
    if [ -z "$update_col" ]; then
        return
    fi
    
    # Extract column name (remove type and PK marker)
    update_col=$(echo "$update_col" | awk '{print $1}')
    
    # Get column info for validation message
    local update_col_idx=0
    local is_primary=0
    local col_type=""
    for ((i=1; i<=col_count; i++)); do
        col_name_var="col${i}_name"
        if [ "${!col_name_var}" = "$update_col" ]; then
            update_col_idx=$i
            col_type_var="col${i}_type"
            col_primary_var="col${i}_primary"
            col_type="${!col_type_var}"
            is_primary=${!col_primary_var}
            break
        fi
    done
    
    # Get new value with informative prompt
    local prompt_text="Enter new value for '$update_col':"
    prompt_text+="\n\nType: $col_type"
    [ $is_primary -eq 1 ] && prompt_text+=" (PRIMARY KEY - must be unique)"
    
    local new_value=$(zenity --entry \
        --title="New Value" \
        --text="$prompt_text" \
        --width=400)
    
    if [ -z "$new_value" ] && [ $is_primary -eq 1 ]; then
        show_error "Primary key cannot be empty!"
        return
    fi
    
    # Validate type
    if [ -n "$new_value" ] && [ "$col_type" = "int" ] && [[ ! "$new_value" =~ ^-?[0-9]+$ ]]; then
        show_error "Column '$update_col' must be integer!"
        return
    fi
    
    # Count matching records
    local data_file="$DB_DIR/$db_name/${table_name}_data"
    local match_count=0
    if [ -f "$data_file" ] && [ -s "$data_file" ]; then
        # Get search column index
        local search_col_idx=0
        for ((i=1; i<=col_count; i++)); do
            col_name_var="col${i}_name"
            if [ "${!col_name_var}" = "$search_col" ]; then
                search_col_idx=$i
                break
            fi
        done
        
        match_count=$(awk -F'|' -v col="$search_col_idx" -v value="$search_value" '
            $col == value {count++} 
            END {print count}
        ' "$data_file")
    fi
    
    if [ "$match_count" -eq 0 ]; then
        show_info "No records found with $search_col = '$search_value'"
        return
    fi
    
    # Show summary and confirm
    local summary="📋 Update Summary\n\n"
    summary+="Table: $table_name\n"
    summary+="🔍 Find: $search_col = '$search_value'\n"
    summary+="✏️ Update: $update_col → '$new_value'\n"
    summary+="📊 Affected records: $match_count\n"
    summary+="⚠️ Primary key constraint: $([ $is_primary -eq 1 ] && echo "YES" || echo "NO")"
    
    if ! confirm_action "$summary" "Confirm Update"; then
        return
    fi
    
    # Perform update using function
    local result
    result=$(update_table_sql "$db_name" "$table_name" "$update_col" "$new_value" "$search_col" "$search_value" 2>&1)
    
    if [ $? -eq 0 ]; then
        show_success "$result"
    else
        show_error "$result"
    fi
}

# SQL MODE GUI
sql_mode_gui() {
    if [ $SQL_PARSER_AVAILABLE -eq 0 ]; then
        show_error "SQL Parser not found!\n\nPlease ensure 'sql_parser.sh' is in the current directory."
        return
    fi
    
    # Ensure SQL_CURRENT_DB is set if we have a current database
    if [ -n "$CURRENT_DB" ] && [ -z "$SQL_CURRENT_DB" ]; then
        SQL_CURRENT_DB="$CURRENT_DB"
    fi
    
    while true; do
        local db_display="${SQL_CURRENT_DB:-none}"
        local sql_command=$(zenity --entry \
            --title="🐬 SQL Mode - DB: $db_display" \
            --text="Enter SQL command:\n(Type 'help' for help, 'exit' to quit, 'show dbs' to list databases)" \
            --width=700 \
            --entry-text="")
        
        if [ -z "$sql_command" ]; then
            break
        fi
        
        # Handle special commands
        case "$sql_command" in
            [Ee][Xx][Ii][Tt])
                break
                ;;
            [Hh][Ee][Ll][Pp])
                show_sql_help_gui
                continue
                ;;
            [Ss][Hh][Oo][Ww][[:space:]]+[Dd][Bb][Ss])
                show_info "$(list_databases)"
                continue
                ;;
            [Uu][Ss][Ee][[:space:]]*)
                # Parse USE command manually
                local db_name=$(echo "$sql_command" | sed -E 's/^[Uu][Ss][Ee][[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*).*/\1/')
                if [ -d "$DB_DIR/$db_name" ]; then
                    SQL_CURRENT_DB="$db_name"
                    show_success "Database changed to '$db_name'"
                else
                    show_error "Database '$db_name' does not exist!"
                fi
                continue
                ;;
        esac
        
        # Execute SQL command
        local output=""
        local exit_code=0
        
        # Use a temp file to capture output
        local temp_output=$(mktemp)
        (parse_sql_command "$sql_command" 2>&1) > "$temp_output"
        exit_code=$?
        
        # Read output
        output=$(cat "$temp_output")
        rm -f "$temp_output"
        
        # Display results
        if [ $exit_code -eq 0 ]; then
            if [ -n "$output" ]; then
                # Check if output looks like table data (contains |)
                if [[ "$output" == *"|"* ]]; then
                    # Format as table
                    local display_file=$(mktemp)
                    echo "$output" > "$display_file"
                    
                    if command -v column &>/dev/null; then
                        local formatted_file=$(mktemp)
                        column -t -s '|' "$display_file" > "$formatted_file" 2>/dev/null || cp "$display_file" "$formatted_file"
                        mv "$formatted_file" "$display_file"
                    fi
                    
                    zenity --text-info \
                        --title="✅ SQL Result" \
                        --filename="$display_file" \
                        --width=800 \
                        --height=500 \
                        --font="$FONT_MONO" \
                        --ok-label="OK"
                    
                    rm -f "$display_file"
                else
                    # Regular output
                    show_success "$output"
                fi
            else
                show_success "Command executed successfully!"
            fi
        else
            show_error "$output"
        fi
    done
}

show_sql_help_gui() {
    local help_text="📚 SQL Command Reference\n\n"
    help_text+="════════════════════════════════════════\n"
    help_text+="DATABASE OPERATIONS:\n"
    help_text+="────────────────────────────────────────\n"
    help_text+="CREATE DATABASE db_name;\n"
    help_text+="USE db_name;\n"
    help_text+="DROP DATABASE db_name;\n\n"
    help_text+="TABLE OPERATIONS:\n"
    help_text+="────────────────────────────────────────\n"
    help_text+="CREATE TABLE table_name (\n"
    help_text+="    col1 TYPE PRIMARY KEY,\n"
    help_text+="    col2 TYPE,\n"
    help_text+="    ...\n"
    help_text+=");\n\n"
    help_text+="DROP TABLE table_name;\n\n"
    help_text+="DATA OPERATIONS:\n"
    help_text+="────────────────────────────────────────\n"
    help_text+="INSERT INTO table_name VALUES (val1, val2, ...);\n"
    help_text+="SELECT * FROM table_name;\n"
    help_text+="SELECT * FROM table_name WHERE col = 'value';\n"
    help_text+="UPDATE table_name SET col = 'new_value' WHERE col = 'value';\n"
    help_text+="DELETE FROM table_name WHERE col = 'value';\n\n"
    help_text+="EXAMPLES:\n"
    help_text+="────────────────────────────────────────\n"
    help_text+="CREATE DATABASE mydb;\n"
    help_text+="USE mydb;\n"
    help_text+="CREATE TABLE users (id int PRIMARY KEY, name string, age int);\n"
    help_text+="INSERT INTO users VALUES (1, 'John', 25);\n"
    help_text+="SELECT * FROM users;\n"
    help_text+="SELECT * FROM users WHERE age > 20;\n"
    help_text+="UPDATE users SET age = 26 WHERE id = 1;\n"
    help_text+="DELETE FROM users WHERE id = 1;\n"
    
    zenity --text-info \
        --title="SQL Help & Syntax Guide" \
        --text="$help_text" \
        --width=700 \
        --height=600 \
        --font="$FONT_MONO"
}

# MAIN MENU
show_welcome_screen() {
    zenity --info \
        --title="🐬 Bash DBMS GUI" \
        --text="✨ Welcome to Bash Database Management System!\n\nManage your databases effortlessly with a clean and intuitive GUI." \
        --width=500 \
        --height=200 \
        --ok-label="Get Started"
}

main_menu_gui() {
    show_welcome_screen
    
    while true; do
        local choice=$(zenity --list \
            --title="🏠 Main Menu - Bash DBMS" \
            --text="Select an operation:" \
            --column="Operation" \
            --column="Description" \
            "📁 Create Database" "Create a new database" \
            "📚 List Databases" "View all databases" \
            "🔗 Connect to DB" "Connect to existing database" \
            "🗑️ Drop Database" "Delete a database" \
            "🐬 SQL Mode" "Execute SQL commands" \
            "ℹ️ System Info" "View system information" \
            "🚪 Exit" "Exit the application" \
            --width=700 \
            --height=450 \
            --ok-label="Select" \
            --cancel-label="Exit")
        
        case "$choice" in
            "📁 Create Database")
                create_database_gui
                ;;
            "📚 List Databases")
                list_databases_gui
                ;;
            "🔗 Connect to DB")
                connect_database_gui
                ;;
            "🗑️ Drop Database")
                drop_database_gui
                ;;
            "🐬 SQL Mode")
                sql_mode_gui
                ;;
            "ℹ️ System Info")
                show_system_info
                ;;
            "🚪 Exit"|"")
                show_exit_screen
                exit 0
                ;;
        esac
    done
}

show_system_info() {
    local info="System Information\n\n"
    info+="═ Database System ════════════════════\n"
    info+="Current Database: ${CURRENT_DB:-None}\n"
    info+="SQL Current DB: ${SQL_CURRENT_DB:-None}\n"
    info+="SQL Parser: $([ $SQL_PARSER_AVAILABLE -eq 1 ] && echo "✅ Available" || echo "❌ Not Available")\n\n"
    
    info+="═ Statistics ════════════════════════\n"
    if [ -d "$DB_DIR" ]; then
        local db_count=$(ls -1 "$DB_DIR" 2>/dev/null | wc -l)
        info+="Total Databases: $db_count\n"
        
        if [ -n "$CURRENT_DB" ] && [ -d "$DB_DIR/$CURRENT_DB" ]; then
            local table_count=$(ls "$DB_DIR/$CURRENT_DB"/*_meta 2>/dev/null | wc -l)
            info+="Tables in '$CURRENT_DB': $table_count\n"
        fi
    else
        info+="No databases created yet\n"
    fi
    
    info+="\n═ System ════════════════════════════\n"
    info+="Shell: $SHELL\n"
    info+="User: $(whoami)\n"
    info+="Hostname: $(hostname)\n"
    info+="Date: $(date)"
    
    zenity --info \
        --title="System Information" \
        --text="$info" \
        --width=500 \
        --height=350
}

show_exit_screen() {
    zenity --info \
        --title="Goodbye 👋" \
        --text="Thank you for using Bash DBMS GUI!\n\nYour databases are safely stored in:\n$DB_DIR" \
        --width=400 \
        --height=200
}

# Check if Zenity is installed
if ! command -v zenity &> /dev/null; then
    echo "Error: Zenity is not installed!"
    echo "Please install Zenity to use the GUI:"
    echo "  Ubuntu/Debian: sudo apt-get install zenity"
    echo "  Fedora/RHEL: sudo dnf install zenity"
    echo "  Arch: sudo pacman -S zenity"
    exit 1
fi

# Create databases directory
mkdir -p "$DB_DIR"

# Clear terminal and start GUI
clear
echo "Starting Bash DBMS GUI..."
sleep 1

# Start the application
main_menu_gui