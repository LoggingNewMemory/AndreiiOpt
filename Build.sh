#!/bin/bash

# Define the two module directories
MODULE_DIRS=("VerBlur" "VerDisBlur")
BUILD_DIR="Build"

# Check if megumi.sh exists and load configuration
TELEGRAM_ENABLED=false
if [ -f "megumi.sh" ]; then
    source megumi.sh
    TELEGRAM_ENABLED=true
fi

mkdir -p "$BUILD_DIR"

welcome() {
    clear
    echo "---------------------------------"
    echo "      Yamada Module Builder      "
    echo "---------------------------------"
    echo ""
}

success() {
    echo "---------------------------------"
    echo "    Build Process Completed      "
    printf "     Ambatukam : %s seconds\n" "$SECONDS"
    echo "---------------------------------"
}

# Function to send file to Telegram
send_to_telegram() {
    local file_path="$1"
    local caption="$2"
    local chat_id="$3"

    if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
        echo "Error: TELEGRAM_BOT_TOKEN is not set in megumi.sh!"
        return 1
    fi

    if [ -z "$chat_id" ]; then
        echo "Error: Chat ID is empty!"
        return 1
    fi

    echo "Uploading $(basename "$file_path") to chat ID: $chat_id..."

    # Send document to Telegram
    response=$(curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendDocument" \
        -F "chat_id=$chat_id" \
        -F "document=@$file_path" \
        -F "caption=$caption")

    # Check if upload was successful
    if echo "$response" | grep -q '"ok":true'; then
        echo "✓ Successfully uploaded $(basename "$file_path") to $chat_id"
        return 0
    else
        echo "✗ Failed to upload $(basename "$file_path") to $chat_id"
        echo "Response: $response"
        return 1
    fi
}

# Function to send message to Telegram
send_message_to_telegram() {
    local message="$1"
    local chat_id="$2"

    if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$chat_id" ]; then
        return 1
    fi

    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d "chat_id=$chat_id" \
        -d "text=$message" \
        -d "parse_mode=Markdown" > /dev/null
}

# Function to display available groups and get selection
select_telegram_groups() {
    local available_groups=()
    local group_names=()

    # Parse TELEGRAM_GROUPS array
    if [ ${#TELEGRAM_GROUPS[@]} -eq 0 ]; then
        echo "No Telegram groups configured in megumi.sh"
        return 1
    fi

    echo ""
    echo "Available Telegram groups:"
    echo "--------------------------"

    local index=1
    for group in "${TELEGRAM_GROUPS[@]}"; do
        # Parse group entry: "GROUP_NAME:CHAT_ID"
        local group_name=$(echo "$group" | cut -d':' -f1)
        local chat_id=$(echo "$group" | cut -d':' -f2)

        available_groups+=("$chat_id")
        group_names+=("$group_name")

        echo "$index. $group_name ($chat_id)"
        ((index++))
    done

    echo "a. All groups"
    echo "0. Cancel"
    echo ""

    while true; do
        read -p "Select groups (comma-separated numbers, 'a' for all, or '0' to cancel): " selection
        selection=${selection,,}  # Convert to lowercase

        if [[ "$selection" == "0" ]]; then
            return 1
        elif [[ "$selection" == "a" || "$selection" == "all" ]]; then
            SELECTED_GROUPS=("${available_groups[@]}")
            SELECTED_GROUP_NAMES=("${group_names[@]}")
            return 0
        else
            # Parse comma-separated selections
            SELECTED_GROUPS=()
            SELECTED_GROUP_NAMES=()
            IFS=',' read -ra SELECTIONS <<< "$selection"

            local valid=true
            for sel in "${SELECTIONS[@]}"; do
                sel=$(echo "$sel" | tr -d '[:space:]')  # Remove whitespace
                if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le ${#available_groups[@]} ]; then
                    local idx=$((sel-1))
                    SELECTED_GROUPS+=("${available_groups[$idx]}")
                    SELECTED_GROUP_NAMES+=("${group_names[$idx]}")
                else
                    echo "Invalid selection: $sel"
                    valid=false
                    break
                fi
            done

            if [ "$valid" = true ] && [ ${#SELECTED_GROUPS[@]} -gt 0 ]; then
                return 0
            fi
        fi

        echo "Please enter valid selections."
    done
}

# Function to prompt for changelog
prompt_changelog() {
    echo ""
    read -p "Give changelog? (Y/N): " ADD_CHANGELOG
    ADD_CHANGELOG=${ADD_CHANGELOG,,}  # Convert to lowercase

    if [[ "$ADD_CHANGELOG" == "y" || "$ADD_CHANGELOG" == "yes" ]]; then
        echo ""
        echo "Enter changelog (press Ctrl+D or type 'END' on a new line when finished):"
        echo "---"

        CHANGELOG=""
        while IFS= read -r line; do
            if [[ "$line" == "END" ]]; then
                break
            fi
            if [ -n "$CHANGELOG" ]; then
                CHANGELOG+=$'\n'
            fi
            CHANGELOG+="$line"
        done

        if [ -n "$CHANGELOG" ]; then
            echo "---"
            echo "Changelog captured successfully!"
            return 0
        else
            echo "No changelog entered."
            return 1
        fi
    else
        return 1
    fi
}

# Function to prompt for Telegram posting
prompt_telegram_post() {
    echo ""
    read -p "Post to Telegram groups? (y/N): " POST_TO_TELEGRAM
    POST_TO_TELEGRAM=${POST_TO_TELEGRAM,,}  # Convert to lowercase

    if [[ "$POST_TO_TELEGRAM" == "y" || "$POST_TO_TELEGRAM" == "yes" ]]; then
        return 0
    else
        return 1
    fi
}

build_modules() {
    rm -rf "$BUILD_DIR"/*

    # Get Version and Build Type ONCE for all modules
    read -p "Enter Version (e.g., V1.0): " VERSION

    while true; do
        read -p "Enter Build Type (LAB/RELEASE): " BUILD_TYPE
        BUILD_TYPE=${BUILD_TYPE^^}
        if [[ "$BUILD_TYPE" == "LAB" || "$BUILD_TYPE" == "RELEASE" ]]; then
            break
        fi
        echo "Invalid input. Please enter LAB or RELEASE."
    done

    # Arrays to store build info for Telegram
    BUILT_ZIPS=()
    BUILT_IDS=()

    # Loop through each module directory
    for MODULE_DIR in "${MODULE_DIRS[@]}"; do
        if [ ! -d "$MODULE_DIR" ]; then
            echo "Warning: Directory $MODULE_DIR does not exist. Skipping."
            continue
        fi

        echo "Building $MODULE_DIR..."
        cd "$MODULE_DIR" || exit 1
        
        # Get ID
        local current_id
        current_id=$(grep "^id=" "module.prop" | cut -d'=' -f2 | tr -d '[:space:]')

        # Update module.prop
        if [ -f "module.prop" ]; then
            cp "module.prop" "module.prop.tmp"
            sed "s/^version=.*$/version=$VERSION/" "module.prop.tmp" > "module.prop"
            rm "module.prop.tmp"
        fi

        # Update customize.sh
        if [ -f "customize.sh" ]; then
            cp "customize.sh" "customize.sh.tmp"
            sed "s/^ui_print \"Version : .*$/ui_print \"Version : $VERSION\"/" "customize.sh.tmp" > "customize.sh"
            rm "customize.sh.tmp"
        fi

        # Create Zip
        local zip_name="${current_id}-${VERSION}-${BUILD_TYPE}.zip"
        local zip_path="../$BUILD_DIR/$zip_name"
        
        zip -q -r "$zip_path" ./*
        echo "Created: $zip_name"
        
        # Add to arrays for Telegram upload
        BUILT_ZIPS+=("$zip_path")
        BUILT_IDS+=("$current_id")

        cd ..
    done

    # Check if Telegram is enabled and we have built files
    if [ "$TELEGRAM_ENABLED" = true ] && [ ${#BUILT_ZIPS[@]} -gt 0 ]; then
        # Prompt for Telegram posting
        if prompt_telegram_post; then
            # Prompt for changelog
            HAS_CHANGELOG=false
            if prompt_changelog; then
                HAS_CHANGELOG=true
            fi

            # Select groups to post to
            if select_telegram_groups; then
                echo ""
                echo "Uploading to selected Telegram groups..."

                # Create a summary message listing all modules
                SUMMARY_MESSAGE="🚀 *Yamada Module Build Complete*%0A%0A"
                
                SUMMARY_MESSAGE+="📦 *Modules Built:*%0A"
                for id in "${BUILT_IDS[@]}"; do
                    SUMMARY_MESSAGE+="   • $id%0A"
                done
                
                SUMMARY_MESSAGE+="🏷️ *Version:* $VERSION%0A"
                SUMMARY_MESSAGE+="🔧 *Build Type:* $BUILD_TYPE%0A"

                # Add changelog if provided
                if [ "$HAS_CHANGELOG" = true ] && [ -n "$CHANGELOG" ]; then
                    ENCODED_CHANGELOG=$(echo "$CHANGELOG" | sed 's/%/%25/g; s/ /%20/g; s/!/%21/g; s/"/%22/g; s/#/%23/g; s/\$/%24/g; s/&/%26/g; s/'\''/%27/g; s/(/%28/g; s/)/%29/g; s/\*/%2A/g; s/+/%2B/g; s/,/%2C/g; s/-/%2D/g; s/\./%2E/g; s/\//%2F/g; s/:/%3A/g; s/;/%3B/g; s/</%3C/g; s/=/%3D/g; s/>/%3E/g; s/?/%3F/g; s/@/%40/g; s/\[/%5B/g; s/\\/%5C/g; s/\]/%5D/g; s/\^/%5E/g; s/_/%5F/g; s/`/%60/g; s/{/%7B/g; s/|/%7C/g; s/}/%7D/g; s/~/%7E/g')
                    ENCODED_CHANGELOG=$(echo "$ENCODED_CHANGELOG" | tr '\n' ' ' | sed 's/ /%0A/g')
                    SUMMARY_MESSAGE+=%0A%0A"📝 *Changelog:*%0A$ENCODED_CHANGELOG"
                fi

                SUMMARY_MESSAGE+=%0A%0A"Files uploading below... ⬇️"

                local upload_success_groups=0
                local upload_total_groups=${#SELECTED_GROUPS[@]}

                # Loop through selected groups
                for i in "${!SELECTED_GROUPS[@]}"; do
                    local chat_id="${SELECTED_GROUPS[$i]}"
                    local group_name="${SELECTED_GROUP_NAMES[$i]}"
                    local group_has_error=false

                    echo ""
                    echo "📤 Posting to: $group_name"

                    # Send summary message first
                    send_message_to_telegram "$SUMMARY_MESSAGE" "$chat_id"

                    # Loop through all built zips and upload them
                    for j in "${!BUILT_ZIPS[@]}"; do
                        local zip_file="${BUILT_ZIPS[$j]}"
                        local mod_id="${BUILT_IDS[$j]}"
                        
                        if [ -f "$zip_file" ]; then
                            caption="📱 $mod_id - $VERSION ($BUILD_TYPE)"
                            if ! send_to_telegram "$zip_file" "$caption" "$chat_id"; then
                                group_has_error=true
                            fi
                        else
                            echo "Error: ZIP file not found at $zip_file"
                            group_has_error=true
                        fi
                    done

                    if [ "$group_has_error" = false ]; then
                         ((upload_success_groups++))
                        COMPLETION_MESSAGE="✅ *Upload Complete!*%0A%0AAll modules uploaded successfully to $group_name."
                        send_message_to_telegram "$COMPLETION_MESSAGE" "$chat_id"
                    else
                        FAILURE_MESSAGE="⚠️ *Upload Incomplete*%0A%0ASome files failed to upload to $group_name."
                        send_message_to_telegram "$FAILURE_MESSAGE" "$chat_id"
                    fi
                done

                echo ""
                echo "📊 Upload Summary:"
                echo "✅ Groups Completed: $upload_success_groups/$upload_total_groups"

            else
                echo "Telegram upload cancelled."
            fi
        else
            echo "Skipping Telegram upload."
        fi
    elif [ "$TELEGRAM_ENABLED" = true ]; then
        echo "No modules were successfully built. Skipping Telegram upload."
    else
        echo ""
        echo "Post to telegram disabled, please setup megumi.sh and configure TELEGRAM_GROUPS array"
    fi
}

welcome
SECONDS=0  # Start timing
build_modules
success