BIND ?= 0.0.0.0
PORT ?= 3001

baseURL ?= ""

check-hugo:
	@command -v hugo > /dev/null 2>&1 || { echo "Hugo is not installed. Please install it first."; exit 1; }
	@echo "Hugo is installed."

new: check-hugo
	@hugo new $(doc)

serve: check-hugo
	@hugo server --minify --theme hugo-book --bind $(BIND) --port $(PORT)

generate: check-hugo
	@hugo --theme hugo-book $(if $(baseURL),--baseURL=$(baseURL))
