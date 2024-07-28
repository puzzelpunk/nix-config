#!/usr/bin/env bash

boolPrompt() {
    # $1 = Var Name
    # $2 = Var Prompt
    # Usage = boolPrompt VAR_NAME PROMPT

    local PROMPT_ANSWER=""
    local PROMPT_VALIDATE="n"
    
    while [ "${PROMPT_VALIDATE}" == "n" ]
    do
        local BOOL="false"

        echo -e "\n"    
        echo -e "${2}"
        echo -e "Enter (y)es or (n)o\n"
        
        read PROMPT_ANSWER 
    
        if [[ "${PROMPT_ANSWER}" == "y" ]]; then
            local BOOL="true"
        fi

        clear 
        echo -e "\n"  
        echo -e "Are you sure you meant to enter ${PROMPT_ANSWER} for ${1}"
        echo -e "Enter (y)es or (n)o\n"
        
        read PROMPT_VALIDATE
         
        if [[ "${PROMPT_VALIDATE}" != "y" ]]; then  
            local PROMPT_VALIDATE="n"
        fi
        clear
    done   

    local  __return_var=$1
    local  return_val=${BOOL}
    eval $__return_var="'$return_val'"
}

# boolPrompt TEST 'THIS IS JUST A TEST, DO YOU UNDERSTAND?'
# echo $TEST 

stringPrompt() {
    # $1 = Var Name
    # $2 = Var Prompt
    # Usage = stringPrompt VAR_NAME PROMPT

    local PROMPT_ANSWER=""
    local PROMPT_VALIDATE="n"
    
    while [ "${PROMPT_VALIDATE}" == "n" ]
    do

        echo -e "\n"    
        echo -e "${2}"
      
        read PROMPT_ANSWER 
    
        clear
        echo -e "\n"  
        echo -e "Are you sure you meant to enter ${PROMPT_ANSWER} for ${1}"
        echo -e "Enter (y)es or (n)o\n"
        
        read PROMPT_VALIDATE
         
        if [[ "${PROMPT_VALIDATE}" != "y" ]]; then              
            local PROMPT_VALIDATE="n"
        fi
        clear
    done   

    local  __return_var=$1
    local  return_val=${PROMPT_ANSWER}
    eval $__return_var="'$return_val'"
}

# stringPrompt TEST_THREE "ENTER A WORD THAT YOU LIKE?"
# echo $TEST_TWO

commandLoopPrompt() {
    # $1 = Command to be ran
    # Usage = commandLoopPrompt COMMAND

    local PROMPT_VALIDATE="n"
    
    while [ "${PROMPT_VALIDATE}" == "n" ]
    do
    	$1
        echo -e "\n"  
        echo -e "Did the previous command '$1' finish without mistakes ?"
        echo -e "Enter (y)es or (n)o\n"
        
        read PROMPT_VALIDATE
         
        if [[ "${PROMPT_VALIDATE}" != "y" ]]; then  
            local PROMPT_VALIDATE="n"
        fi
        clear
    done   
}
# commandLoopPrompt "echo hello world"
