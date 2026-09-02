
build:
	cd charts/kubecraft && \
		helm package . && \
		for package in *.tgz; do mv "$$package" "../../$$package.new"; done

index:
	helm repo index . --url https://kawamanza.github.io/kubecraft
