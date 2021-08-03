

## Title: Alternate Borgs

MODULE ID: ALTBORGS

### Description:

Adds all alternate borg presets to the game, ported from Skyrat to HRZN

### TG Proc Changes:
- APPEND: modular_skyrat/modules/altborgs/code/modules/mob/living/silicon/robot/robot.dm > /mob/living/silicon/robot/doMove()
- ADDITION: code\modules\mob\living\silicon\robot\robot_modules.dm > /obj/item/robot_module/proc/transform_to(new_module_type)

### Defines:

- #define JOB_DISPLAY_ORDER_BLUESHIELD 34
- #define ACCESS_BLUESHIELD 71

### Master file additions

- N/A

### Included files that are not contained in this module:

- N/A

### Credits:

Gandalf2k15 - Porting & refactoring
MissFox - Porting and cleanup
