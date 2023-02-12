case "$1" in
e)	vi -p replicate.bash docker-compose.yaml
	;;
r)	./replicate.bash
	;;
"")	set -x
	docker-compose up -d
	timeout 3 docker-compose logs -f
	;;
esac
