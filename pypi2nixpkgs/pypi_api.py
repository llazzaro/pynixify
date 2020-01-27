import hashlib
import tempfile
import aiohttp
import aiofiles
from typing import Sequence
from pathlib import Path
from dataclasses import dataclass
from urllib.parse import quote, urlparse
from packaging.utils import canonicalize_name
from packaging.requirements import Requirement
from packaging.version import Version, parse
from pypi2nixpkgs.exceptions import (
    IntegrityError
)


@dataclass
class PyPIPackage:
    version: Version
    sha256: str
    download_url: str
    pypi_cache: object

    async def download_source(self) -> Path:
        filename = tempfile.mktemp(
            prefix='pypi2nixpkgs_download',
            suffix=self.filename,
        )
        downloaded_file: Path = await self.pypi_cache.fetch_url(
            self.download_url, filename)
        h = hashlib.sha256()
        with downloaded_file.open('rb') as fp:
            while True:
                data = fp.read(65536)
                if not data:
                    break
                h.update(data)
        if h.hexdigest() != self.sha256:
            raise IntegrityError(
                f"SHA256 hash does not match. The hash of {self.download_url} "
                f"should be {self.sha256} but it is {h.hexdigest()} instead."
            )
        return downloaded_file

    @property
    def filename(self):
        return Path(urlparse(self.download_url).path).name


class PyPIData:
    def __init__(self, pypi_cache):
        self.pypi_cache = pypi_cache

    async def from_requirement(self, req: Requirement) -> Sequence[PyPIPackage]:
        response = await self.pypi_cache.fetch(canonicalize_name(req.name))
        matching = []
        for (version, version_dist) in response['releases'].items():
            try:
                data = next(e for e in version_dist if e['packagetype'] == 'sdist')
            except StopIteration:
                continue
            if version in req.specifier:
                matching.append(PyPIPackage(
                    sha256=data['digests']['sha256'],
                    version=parse(version),
                    download_url=data['url'],
                    pypi_cache=self.pypi_cache,
                ))
        return matching


class PyPICache:
    async def fetch(self, package_name):
        url = f'https://pypi.org/pypi/{quote(package_name)}/json'
        async with aiohttp.ClientSession(raise_for_status=True) as session:
            async with session.get(url) as response:
                return await response.json()

    async def fetch_url(self, url, filename):
        async with aiohttp.ClientSession(raise_for_status=True) as session:
            async with session.get(url) as response:
                async with aiofiles.open(filename, 'wb') as fp:
                    while True:
                        data = await response.content.read(65535)
                        if not data:
                            break
                        await fp.write(data)
                return Path(filename)
