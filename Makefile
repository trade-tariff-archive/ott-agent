.PHONY: build run shell test db-migrate db-reset

build:
	docker compose build

run:
	docker compose up

shell:
	docker compose run --rm app sh

test:
	bundle exec rspec

db-migrate:
	bundle exec rails db:migrate

db-reset:
	bundle exec rails db:drop db:create db:migrate
