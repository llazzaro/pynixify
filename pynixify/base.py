# pynixify - Nix expression generator for Python packages
# Copyright (C) 2020 Matías Lang

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

import json
from pathlib import Path
from dataclasses import dataclass
from typing import Optional, Dict
from packaging.version import Version

@dataclass
class PackageMetadata:
    description: Optional[str]
    license: Optional[str]
    url: Optional[str]

@dataclass
class Package:
    version: Version

    async def source(self, extra_args=[]) -> Path:
        raise NotImplementedError()

    @property
    def attr(self) -> str:
        raise NotImplementedError()

    async def metadata(self) -> PackageMetadata:
        from pynixify.package_requirements import run_nix_build, NixBuildError
        source = await self.source()
        nix_expression_path = Path(__file__).parent / "data" / "parse_setuppy_data.nix"
        assert nix_expression_path.exists()
        nix_store_path = await run_nix_build(
            str(nix_expression_path),
            '--no-out-link',
            '--no-build-output',
            '--arg',
            'file',
            str(source.resolve())
        )
        if (nix_store_path / 'failed').exists():
            print(f'Error parsing metadata of {source}. Assuming it has no metadata.')
            return PackageMetadata(
                url=None,
                description=None,
                license=None,
            )
        with (nix_store_path / 'meta.json').open() as fp:
            return PackageMetadata(**json.load(fp))
