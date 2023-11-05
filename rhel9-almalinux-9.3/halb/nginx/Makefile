APP := ngx

build:
	cat ${APP}.deploy.yaml ${APP}.cm.yaml ${APP}.svc.yaml |tee ${APP}.yaml

deploy:
	kubectl apply -f ${APP}.yaml 

deployeach:
	kubectl apply -f ${APP}.deploy.yaml -f ${APP}.cm.yaml -f ${APP}.svc.yaml 




