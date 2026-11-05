"""Bank-scoped API key authentication and authorization extension for Hindsight.

Granularity B (single PostgreSQL schema, per-key bank allowlist):
- Supports loading a flat JSON policy file (`HINDSIGHT_API_TENANT_KEYS_FILE` /
  `HINDSIGHT_API_OPERATION_VALIDATOR_KEYS_FILE`, or `CREDENTIALS_DIRECTORY/keys.json`)
  mapping each API key to the bank(s) it can access:
  - `{"<api_key>": "*"}` or `{"<api_key>": ["*"]}` -> admin (all banks allowed)
  - `{"<api_key>": ["bank1", "bank2"]}` or `{"<api_key>": "bank1"}` -> only listed banks
"""

from __future__ import annotations

import hmac
import json
import os
from pathlib import Path
from typing import TYPE_CHECKING, Any

from hindsight_api.config import get_config
from hindsight_api.extensions.operation_validator import (
    BankListContext,
    BankListResult,
    BankListScope,
    BankReadContext,
    BankWriteContext,
    ConsolidateContext,
    CreateBankContext,
    ImportContext,
    MemoryUpdateContext,
    MentalModelGetContext,
    MentalModelRefreshContext,
    OperationValidatorExtension,
    PrecheckContext,
    RecallContext,
    ReflectContext,
    RetainContext,
    ValidationResult,
)
from hindsight_api.extensions.tenant import (
    AuthenticationError,
    Tenant,
    TenantContext,
    TenantExtension,
)

if TYPE_CHECKING:
    from hindsight_api.models import RequestContext


def _ingest_key_target(
    token: str,
    target: Any,
    admin_keys: set[str],
    bank_map: dict[str, set[str]],
) -> None:
    token = token.strip()
    if not token:
        return
    if target == "*":
        admin_keys.add(token)
        return
    if isinstance(target, str):
        items = [part.strip() for part in target.split(",") if part.strip()]
    elif isinstance(target, list):
        items = [str(part).strip() for part in target if str(part).strip()]
    else:
        raise ValueError(f"Invalid bank specification for API key: expected str or list[str], got {type(target).__name__}")

    if "*" in items:
        admin_keys.add(token)
    else:
        for bank_id in items:
            bank_map.setdefault(token, set()).add(bank_id)


def _parse_policy(
    config: dict[str, str],
    env_prefix: str = "HINDSIGHT_API_TENANT_",
) -> tuple[set[str], dict[str, set[str]]]:
    """Build `(admin_keys, token -> allowed_bank_ids)` from flat JSON file."""
    merged: dict[str, str] = {}
    for k, v in os.environ.items():
        if k.startswith(env_prefix) and k != f"{env_prefix}EXTENSION":
            merged[k[len(env_prefix) :].lower()] = v
    merged.update({k.lower(): v for k, v in config.items()})

    admin_keys: set[str] = set()
    bank_map: dict[str, set[str]] = {}

    keys_file = merged.get("keys_file", "").strip()
    if not keys_file:
        cred_dir = os.environ.get("CREDENTIALS_DIRECTORY", "").strip()
        if cred_dir:
            candidate = Path(cred_dir) / "keys.json"
            if candidate.is_file():
                keys_file = str(candidate)

    if keys_file:
        data = json.loads(Path(keys_file).read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            raise ValueError("Hindsight keys JSON root must be a flat JSON object")
        for token, target in data.items():
            _ingest_key_target(str(token), target, admin_keys, bank_map)

    return admin_keys, bank_map


def _match_token(
    provided: str | None,
    admin_keys: set[str],
    bank_map: dict[str, set[str]],
) -> tuple[bool, set[str] | None]:
    """Return `(authenticated, allowed_banks)`.

    `allowed_banks` is `None` for admin keys (all banks allowed), or a `set[str]`
    of permitted bank IDs for scoped keys.
    """
    if not provided:
        return False, None

    is_admin = False
    for admin_key in admin_keys:
        if hmac.compare_digest(provided, admin_key):
            is_admin = True

    allowed: set[str] = set()
    for token, banks in bank_map.items():
        if hmac.compare_digest(provided, token):
            allowed.update(banks)

    if is_admin:
        return True, None
    if allowed:
        return True, allowed
    return False, None


class BankKeyTenantExtension(TenantExtension):
    """Authenticate requests against admin or per-bank API keys in a shared schema."""

    def __init__(self, config: dict[str, str]):
        super().__init__(config)
        self.admin_keys, self.bank_map = _parse_policy(config)
        if not self.admin_keys and not self.bank_map:
            raise ValueError(
                "At least one API key must be configured via HINDSIGHT_API_TENANT_KEYS_FILE "
                "or $CREDENTIALS_DIRECTORY/keys.json"
            )
        self.mcp_auth_disabled = config.get("mcp_auth_disabled", "").lower() in (
            "true",
            "1",
            "yes",
        )

    async def authenticate(self, context: RequestContext) -> TenantContext:
        ok, allowed_banks = _match_token(context.api_key, self.admin_keys, self.bank_map)
        if not ok:
            raise AuthenticationError("Invalid API key")
        if allowed_banks is None:
            context.tenant_id = "admin"
        else:
            context.tenant_id = "banks:" + ",".join(sorted(allowed_banks))
        return TenantContext(schema_name=get_config().database_schema)

    async def list_tenants(self) -> list[Tenant]:
        return [Tenant(schema=get_config().database_schema)]

    async def authenticate_mcp(self, context: RequestContext) -> TenantContext:
        if self.mcp_auth_disabled:
            return TenantContext(schema_name=get_config().database_schema)
        return await self.authenticate(context)


class BankScopeValidator(OperationValidatorExtension):
    """Restrict each API key to its permitted `bank_id` set (Granularity B)."""

    def __init__(self, config: dict[str, str]):
        super().__init__(config)
        self.admin_keys, self.bank_map = _parse_policy(config)

    def _allowed_banks(self, request_context: RequestContext | None) -> set[str] | None:
        """Return `None` if unrestricted (internal/admin), or the allowed bank set."""
        if request_context is None or request_context.internal:
            return None
        ok, allowed = _match_token(request_context.api_key, self.admin_keys, self.bank_map)
        if not ok:
            return set()
        return allowed

    def _check_bank(self, bank_id: str, request_context: RequestContext | None) -> ValidationResult:
        allowed = self._allowed_banks(request_context)
        if allowed is None or bank_id in allowed:
            return ValidationResult.accept()
        return ValidationResult.reject(
            f"API key is not authorized for bank '{bank_id}'",
            status_code=403,
        )

    async def precheck(self, ctx: PrecheckContext) -> ValidationResult:
        return self._check_bank(ctx.bank_id, ctx.request_context)

    async def validate_retain(self, ctx: RetainContext) -> ValidationResult:
        return self._check_bank(ctx.bank_id, ctx.request_context)

    async def validate_recall(self, ctx: RecallContext) -> ValidationResult:
        return self._check_bank(ctx.bank_id, ctx.request_context)

    async def validate_reflect(self, ctx: ReflectContext) -> ValidationResult:
        return self._check_bank(ctx.bank_id, ctx.request_context)

    async def validate_consolidate(self, ctx: ConsolidateContext) -> ValidationResult:
        return self._check_bank(ctx.bank_id, ctx.request_context)

    async def validate_mental_model_get(self, ctx: MentalModelGetContext) -> ValidationResult:
        return self._check_bank(ctx.bank_id, ctx.request_context)

    async def validate_mental_model_refresh(self, ctx: MentalModelRefreshContext) -> ValidationResult:
        return self._check_bank(ctx.bank_id, ctx.request_context)

    async def validate_memory_update(self, ctx: MemoryUpdateContext) -> ValidationResult:
        return self._check_bank(ctx.bank_id, ctx.request_context)

    async def validate_bank_read(self, ctx: BankReadContext) -> ValidationResult:
        return self._check_bank(ctx.bank_id, ctx.request_context)

    async def validate_bank_write(self, ctx: BankWriteContext) -> ValidationResult:
        return self._check_bank(ctx.bank_id, ctx.request_context)

    async def validate_create_bank(self, ctx: CreateBankContext) -> ValidationResult:
        return self._check_bank(ctx.bank_id, ctx.request_context)

    async def validate_import(self, ctx: ImportContext) -> ValidationResult:
        return self._check_bank(ctx.bank_id, ctx.request_context)

    async def bank_list_scope(self, request_context: RequestContext) -> BankListScope | None:
        allowed = self._allowed_banks(request_context)
        if allowed is None:
            return BankListScope(bank_ids=None)
        return BankListScope(bank_ids=sorted(allowed))

    async def filter_bank_list(self, ctx: BankListContext) -> BankListResult:
        allowed = self._allowed_banks(ctx.request_context)
        if allowed is None:
            return BankListResult(banks=ctx.banks)
        return BankListResult(
            banks=[b for b in ctx.banks if b.get("bank_id") in allowed]
        )
