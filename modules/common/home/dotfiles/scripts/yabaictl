#!/usr/bin/env node
const system = require('child_process')
const fs = require('fs')

const RESIZE_AMOUNT = 100
const SPACES_PER_DISPLAY = 3

/**
* Function to issue bash commands, returns the stdout.
* @param command
* @returns {string} stdout
*/
function shell (command, ...args) {
  const shell_args = args.length ? args : []
  let shell_out = ''
  try {
    shell_out = system.spawnSync(command, shell_args)
  } catch(error) {
    shell_out = error
  }

  return {
    status: shell_out.status,
    stdout: shell_out?.stdout?.toString(),
    stderr: shell_out?.stderr?.toString()
  }
}

function yabai_message(type, action, subaction = '', modifier = '') {
  return shell('/opt/homebrew/bin/yabai', '-m', type, `--${action}`, subaction, modifier)
}

function spaces_on_display (index = '') {
  return JSON.parse(yabai_message('query', 'spaces', '--display', index).stdout)
}

function space_current_index () {
  const { index } = JSON.parse(yabai_message('query', 'spaces', '--space').stdout)
  return index
}

function window_current_id () {
  const { id } = JSON.parse(yabai_message('query', 'windows', '--window').stdout)
  return id
}

function space_next (direction) {
  const spaces = spaces_on_display()
  const index = space_current_index()

  const index_next = direction === 'north'
    ? index + 1
    : index - 1
  
  const index_first = spaces[0].index
  const index_last = spaces[spaces.length - 1].index

  if (index_next > index_last) {
    return index_first
  } else if (index_next < index_first) {
    return index_last
  } else {
    return index_next
  }
}

function displays_on_system () {
  return JSON.parse(yabai_message('query', 'displays', '').stdout)
}

function display_current_index () {
  const { index } = JSON.parse(yabai_message('query', 'displays', '--display').stdout)
  return index
}

function display_next (direction) {
  const displays = displays_on_system()
  const index = display_current_index()

  const index_next = direction === 'east'
    ? index + 1
    : index - 1
  
  const index_first = displays[0].index
  const index_last = displays[displays.length - 1].index

  if (index_next > index_last) {
    return index_first
  } else if (index_next < index_first) {
    return index_last
  } else {
    return index_next
  }
}

function workspace_is_empty () {
  return JSON.parse(yabai_message('query', 'windows', '--space').stdout)
    .filter(({ floating, visible, minimized }) => 
      floating !== 1 && 
      visible !== 0 &&
      minimized !== 1
    ).length === 0
}

function position_adjacent (direction) {
  switch(direction) {
    case "east":
      return "first"
    case "west":
      return "last"
    case "south":
      return "first"
    case "north":
      return "last"
  }
}

function yabai_focus(direction) {
  const focus_adjacent_window = yabai_message('window', 'focus', direction)

  if (focus_adjacent_window.status !== 0) {
    if (direction === 'east' || direction === 'west') {
      const index = display_next(direction)

      yabai_message('display', 'focus', index)
    } else if (direction === 'north' || direction === 'south') {
      const index = space_next(direction)

      yabai_message('space', 'focus', index)
    }

    if (!workspace_is_empty()) {
      const position = position_adjacent(direction)
      yabai_message('window', 'focus', position)
    }
  }
}

function yabai_move(direction) {
  const warp_adjacent_window = yabai_message('window', 'swap', direction)
  
  if (warp_adjacent_window.status !== 0) {
    const id = window_current_id()

    if (direction === 'east' || direction === 'west') {
      const index = display_next(direction)
      
      yabai_message('window', 'display', index)
      yabai_message('display', 'focus', index)
      
    } else if (direction === 'north' || direction === 'south') {
      const index = space_next(direction)
      
      yabai_message('window', 'space', index)
      yabai_message('space', 'focus', index)
    }

    const position = position_adjacent(direction)
    yabai_message('window', 'warp', position)
    yabai_message('window', 'focus', id)
  }
}

function yabai_resize(direction) {
  if (direction === 'west') {
    const resize_west = yabai_message('window', 'resize', `left:-${RESIZE_AMOUNT}:0`)

    if (resize_west.status !== 0) {
      yabai_message('window', 'resize', `right:-${RESIZE_AMOUNT}:0`)
    }
  } else if (direction === 'east') {
    const resize_east = yabai_message('window', 'resize', `left:${RESIZE_AMOUNT}:0`)

    if (resize_east.status !== 0) {
      yabai_message('window', 'resize', `right:${RESIZE_AMOUNT}:0`)
    }
  } else if (direction === 'north') {
    const resize_north = yabai_message('window', 'resize', `bottom:0:-${RESIZE_AMOUNT}`)

    if (resize_north.status !== 0) {
      yabai_message('window', 'resize', `top:0:-${RESIZE_AMOUNT}`)
    }
  } else if (direction === 'south') {
    const resize_south = yabai_message('window', 'resize', `bottom:0:${RESIZE_AMOUNT}`)

    if (resize_south.status !== 0) {
      yabai_message('window', 'resize', `top:0:${RESIZE_AMOUNT}`)
    }
  }
}

function yabai_create_workspaces() {
  const display_initial = display_current_index()
  const space_initial = space_current_index()

  const displays = displays_on_system()

  for (let i = 0; i < displays.length; i++) {
    const di = i + 1

    yabai_message('display', 'focus', di)

    const spaces = spaces_on_display()

    for (let k = 0; k <= SPACES_PER_DISPLAY; k++) {
      if (k > spaces.length) {
        yabai_message('space', 'create')
      }
    }
  }
  
  yabai_message('display', 'focus', display_initial)
  yabai_message('space', 'focus', space_initial)
}

async function main () {
  const args = process.argv
  const action = args[2]
  const direction = args[3]

  switch (action) {
    case 'focus':
      yabai_focus(direction)  
      break
    case 'move':
      yabai_move(direction)
      break
    case 'resize':
      yabai_resize(direction)
      break
    case 'create_workspaces':
      yabai_create_workspaces()
      break
  }
}

try {
  main()
} catch (error) {
  console.error(error)
}
