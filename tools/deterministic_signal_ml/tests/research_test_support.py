from __future__ import annotations

import csv
import shutil
from pathlib import Path

import duckdb

from build_dataset import create_dataset_tables, write_parquet_outputs
from report_writer import (
    build_quality_payload,
    write_dataset_manifest,
    write_dataset_report,
    write_quality_json,
)
from schema_contract import validate_run


def copy_run_with_id(source: Path, runs_root: Path, run_id: str) -> Path:
    target = runs_root / run_id
    shutil.copytree(source, target)
    for path in target.glob("*.tsv"):
        with path.open("r", encoding="utf-8", newline="") as handle:
            reader = csv.DictReader(handle, delimiter="\t")
            columns = list(reader.fieldnames or ())
            rows = list(reader)
        for row in rows:
            if "run_id" in row:
                row["run_id"] = run_id
            if path.name == "run_manifest.tsv" and row["key"] == "run_id":
                row["value"] = run_id
        with path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(
                handle,
                fieldnames=columns,
                delimiter="\t",
                lineterminator="\n",
            )
            writer.writeheader()
            writer.writerows(rows)
    return target


def build_fixture_dataset(
    fixture: Path,
    output_dir: Path,
    dataset_id: str = "fixture_v13",
) -> dict[str, int]:
    output_dir.mkdir(parents=True)
    validation = validate_run(fixture.parent, fixture.name)
    connection = duckdb.connect(":memory:")
    try:
        counts = create_dataset_tables(connection, [validation])
        output_files = write_parquet_outputs(connection, output_dir, counts)
        quality = build_quality_payload(connection, [validation], counts)
        write_dataset_manifest(
            output_dir,
            dataset_id,
            [validation],
            counts,
            output_files,
            quality,
        )
        write_quality_json(output_dir, quality)
        write_dataset_report(output_dir, dataset_id, quality)
    finally:
        connection.close()
    return counts
