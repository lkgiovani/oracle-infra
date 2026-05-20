SHELL := $(shell command -v bash)
.ONESHELL:
.SHELLFLAGS := -euo pipefail -c

ROOT          := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
ENV           := prod
PROD_DIR      := $(ROOT)/infra/envs/$(ENV)
VCN_DIR       := $(PROD_DIR)/vcn
IAM_DIR       := $(PROD_DIR)/iam
COMPUTE_DIR   := $(PROD_DIR)/compute
NS_DIR        := $(PROD_DIR)/k8s/namespaces
SECRETS_DIR   := $(PROD_DIR)/k8s/secrets
HELM_DIR      := $(PROD_DIR)/k8s/helm

AGE_KEY       := $(SECRETS_DIR)/keys/age.key
ENCRYPT_SH    := $(SECRETS_DIR)/scripts/encrypt.sh
DECRYPT_SH    := $(SECRETS_DIR)/scripts/decrypt.sh
KUBECONFIG_SH := $(ROOT)/scripts/get-kubeconfig.sh

TF            ?= terraform
TF_ARGS       ?= -auto-approve

.PHONY: help all vcn iam compute kubeconfig namespaces secrets helm \
        encrypt decrypt destroy destroy-helm destroy-secrets \
        destroy-namespaces destroy-compute destroy-iam destroy-vcn \
        init-all fmt validate

help:
	@echo "Targets:"
	@echo "  all            vcn -> iam -> compute -> kubeconfig -> namespaces -> secrets -> helm"
	@echo "  vcn            terraform apply in $(VCN_DIR)"
	@echo "  iam            terraform apply in $(IAM_DIR)"
	@echo "  compute        terraform apply in $(COMPUTE_DIR)"
	@echo "  kubeconfig     pull kubeconfig from k3s node"
	@echo "  namespaces     terraform apply in $(NS_DIR)"
	@echo "  secrets        terraform apply in $(SECRETS_DIR) (SOPS_AGE_KEY_FILE set)"
	@echo "  helm           terraform apply in $(HELM_DIR)"
	@echo "  encrypt        run $(ENCRYPT_SH)"
	@echo "  decrypt        run $(DECRYPT_SH)"
	@echo "  init-all       terraform init in every layer"
	@echo "  fmt | validate terraform fmt/validate across layers"
	@echo "  destroy-*      tear down individual layer"
	@echo "  destroy        full teardown (reverse order)"

define tf_apply
	cd $(1)
	$(TF) init
	$(TF) apply $(TF_ARGS)
endef

define tf_destroy
	cd $(1)
	$(TF) init
	$(TF) destroy $(TF_ARGS)
endef

all: vcn iam compute kubeconfig namespaces secrets helm

vcn:
	$(call tf_apply,$(VCN_DIR))

iam:
	$(call tf_apply,$(IAM_DIR))

compute:
	$(call tf_apply,$(COMPUTE_DIR))

kubeconfig:
	@echo ">> waiting for k3s bootstrap (sleep 180s)"
	sleep 180
	bash $(KUBECONFIG_SH)

namespaces:
	$(call tf_apply,$(NS_DIR))

secrets:
	@test -f $(AGE_KEY) || { echo "missing age key: $(AGE_KEY)"; exit 1; }
	cd $(SECRETS_DIR)
	$(TF) init
	SOPS_AGE_KEY_FILE=$(AGE_KEY) $(TF) apply $(TF_ARGS)

helm:
	$(call tf_apply,$(HELM_DIR))

encrypt:
	cd $(SECRETS_DIR)
	SOPS_AGE_KEY_FILE=$(AGE_KEY) bash $(ENCRYPT_SH)

decrypt:
	cd $(SECRETS_DIR)
	SOPS_AGE_KEY_FILE=$(AGE_KEY) bash $(DECRYPT_SH)

init-all:
	for d in $(VCN_DIR) $(IAM_DIR) $(COMPUTE_DIR) $(NS_DIR) $(SECRETS_DIR) $(HELM_DIR); do
	  echo ">> init $$d"
	  (cd $$d && $(TF) init)
	done

fmt:
	$(TF) fmt -recursive $(ROOT)/infra

validate:
	for d in $(VCN_DIR) $(IAM_DIR) $(COMPUTE_DIR) $(NS_DIR) $(SECRETS_DIR) $(HELM_DIR); do
	  echo ">> validate $$d"
	  (cd $$d && $(TF) init -backend=false >/dev/null && $(TF) validate)
	done

destroy-helm:
	$(call tf_destroy,$(HELM_DIR))

destroy-secrets:
	cd $(SECRETS_DIR)
	$(TF) init
	SOPS_AGE_KEY_FILE=$(AGE_KEY) $(TF) destroy $(TF_ARGS)

destroy-namespaces:
	$(call tf_destroy,$(NS_DIR))

destroy-compute:
	$(call tf_destroy,$(COMPUTE_DIR))

destroy-iam:
	$(call tf_destroy,$(IAM_DIR))

destroy-vcn:
	$(call tf_destroy,$(VCN_DIR))

destroy: destroy-helm destroy-secrets destroy-namespaces destroy-compute destroy-iam destroy-vcn
