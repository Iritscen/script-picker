# ScriptPicker
An interactive menu for quickly finding and setting up an invocation for one of the Unix scripts found in a directory. You must write a file, referred to in the script as a read-me, which contains various metadata on the scripts. When ScriptPicker is passed the path to the read-me, a menu is offered for browsing the scripts by category. When a script is chosen, the invocation of said script is started for you on the command line. Multiple paths to read-mes in different directories of scripts can be passed to ScriptPicker, and the scripts will all be presented together by category.

For information on how to format the read-me, see the comment header in the script. The file "[README](https://github.com/Iritscen/small-scripts/blob/master/Bash/README.md)" in my "Bash/Small scripts" repository is an example of such a read-me. When you run this script and it successfully confirms that the list of scripts in the read-me matches the files in the directory, the first thing you'll see is the menu. After choosing a category, you can pick a script in that category:

![Menu](https://github.com/Iritscen/script-picker/blob/master/preview1.jpg)


After choosing a script, you are returned to the command prompt and the invocation of the script is typed into Terminal via AppleScript:

![Invocation](https://github.com/Iritscen/script-picker/blob/master/preview2.jpg)


Note that this script is "me-ware" and is designed for my own usage, so it outputs "rb ___.sh", which is referring to an alias I have on my command line that is basically equivalent to "cd script_directory;bash ___.sh". You'll obviously need to customize that part for your own environment.