## ----------------------------------------------------------------------
## This makefile can be used to execute common functions to interact with
## the source code, these functions ease local development and can also be
## used in CI/CD pipelines.
## ----------------------------------------------------------------------

mysql_root_password=sql_blog_audit
docker_args=-l error #default args, supresses warnings

# REFERENCE: https://stackoverflow.com/questions/16931770/makefile4-missing-separator-stop
help: ## Show this help.
	@sed -ne '/@sed/!s/## //p' $(MAKEFILE_LIST)

run: ## run sql_blog_audit
	@docker ${docker_args} container rm -f mysql
	@docker ${docker_args} image prune -f
	@docker ${docker_args} compose up -d --wait

stop: ## stop sql_blog_audit
	@docker ${docker_args} compose down

clean: stop ## stop and clean docker resources
	@docker ${docker_args} compose rm -f --volumes
	@docker ${docker_args} volume prune -f
