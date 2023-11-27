##############################################################################
# Makefile.settings : Environment Variables for Makefile(s)
##############################################################################
# Environment variable rules:
# - Any TRAILING whitespace KILLS its variable value and may break recipes.
# - ESCAPE only that required by the shell (bash).
# - Environment Hierarchy:
#   - Makefile environment OVERRIDEs OS environment lest set using `?=`.
#  	  - `FOO ?= bar` is overridden by parent setting.
#  	  - `FOO :=`bar` is NOT overridden by parent setting.
#   - Docker YAML `env_file:` OVERRIDEs OS and Makefile environments.
#   - Docker YAML `environment:` OVERRIDEs YAML `env_file:`.
#   - CMDline OVERRIDEs ALL, e.g., `make recipeX FOO=newValue BAR=newToo`.

##############################################################################
# $(INFO) : Usage : `$(INFO) 'What ever'` prints a stylized "@ What ever".
SHELL   := /bin/bash
YELLOW  := "\e[1;33m"
RESTORE := "\e[0m"
INFO    := @bash -c 'printf $(YELLOW);echo "@ $$1";printf $(RESTORE)' MESSAGE

##############################################################################
# Project Meta

export PRJ_ROOT := $(shell pwd)

##############################################################################
# Recipes : Meta

menu :
	$(INFO) 'Meta'
	@echo "html      : .MD -> .HTML"
	@echo "push      : gc && git push"
	
# $(INFO) 'Environment'
# @echo "PWD=${PRJ_ROOT}"
# @env |grep APP_
# @env |grep _IMAGE |grep -v APP_IMAGE

push :
	gc && echo && git push

html : md2html perms

md2html :
	find . -type f ! -path './.git/*' -iname '*.md' -exec md2html.exe {} \;

perms :
	find . -type f ! -path './.git/*' -iname '*.html' -exec chmod 0644 "{}" \+

#####################################################
# Each affected file has mtime RESET by `make perms`
#####################################################
# find . -type f ! -path './.git/*' -exec chmod 0644 "{}" \+
# find . -type f ! -path './.git/*' -iname '*.sh' -exec chmod 0755 "{}" \+
