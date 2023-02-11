case "$1" in
e)	vi -p replicate.bash docker-compose.yaml
	;;
"")	set -x
	docker-compose up -d
	timeout 3 docker-compose logs -f
	;;
esac
