"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { geoMercator, geoPath } from "d3-geo";
import { feature } from "topojson-client";
import statesTopology from "us-atlas/states-10m.json";
import type { ComplianceStatus, CondoAssociation } from "@/lib/types";

type UnitBucket = "All" | "25-99" | "100-249" | "250+";
type StatusBucket = "All" | ComplianceStatus;

type FloridaMapDashboardProps = {
  associations: CondoAssociation[];
};

type Marker = {
  association: CondoAssociation;
  x: number;
  y: number;
  radius: number;
};

const MAP_WIDTH = 760;
const MAP_HEIGHT = 460;
const FLORIDA_STATE_FIPS = 12;

function matchesUnitBucket(units: number, bucket: UnitBucket): boolean {
  if (bucket === "All") return true;
  if (bucket === "25-99") return units >= 25 && units <= 99;
  if (bucket === "100-249") return units >= 100 && units <= 249;
  return units >= 250;
}

function markerClass(status: ComplianceStatus): string {
  if (status === "Compliant") return "fl-map-marker fl-map-marker-good";
  if (status === "At Risk") return "fl-map-marker fl-map-marker-warn";
  return "fl-map-marker fl-map-marker-bad";
}

function statusPillClass(status: ComplianceStatus): string {
  if (status === "Compliant") return "pill pill-green";
  if (status === "At Risk") return "pill pill-yellow";
  return "pill pill-red";
}

export function FloridaMapDashboard({ associations }: FloridaMapDashboardProps) {
  const [statusFilter, setStatusFilter] = useState<StatusBucket>("All");
  const [countyFilter, setCountyFilter] = useState<string>("All");
  const [unitFilter, setUnitFilter] = useState<UnitBucket>("All");
  const [searchFilter, setSearchFilter] = useState("");
  const [selectedAssociationId, setSelectedAssociationId] = useState<string | null>(null);

  const floridaFeature = useMemo(() => {
    const topology = statesTopology as unknown as {
      objects: { states: unknown };
    };
    const stateFeatures = feature(topology as never, topology.objects.states as never) as {
      features?: Array<{ id?: number | string }>;
    };

    return (
      stateFeatures.features?.find((item) => Number(item.id) === FLORIDA_STATE_FIPS) ?? null
    );
  }, []);

  const projection = useMemo(() => {
    if (!floridaFeature) return null;
    return geoMercator().fitExtent(
      [
        [18, 18],
        [MAP_WIDTH - 18, MAP_HEIGHT - 18],
      ],
      floridaFeature as never,
    );
  }, [floridaFeature]);

  const floridaPath = useMemo(() => {
    if (!projection || !floridaFeature) return "";
    const pathGenerator = geoPath(projection);
    return pathGenerator(floridaFeature as never) || "";
  }, [projection, floridaFeature]);

  const countyOptions = useMemo(() => {
    const values = [...new Set(associations.map((item) => item.county).filter(Boolean))];
    return values.sort((a, b) => a.localeCompare(b));
  }, [associations]);

  const filteredAssociations = useMemo(() => {
    const search = searchFilter.trim().toLowerCase();
    return associations.filter((item) => {
      if (statusFilter !== "All" && item.complianceStatus !== statusFilter) return false;
      if (countyFilter !== "All" && item.county !== countyFilter) return false;
      if (!matchesUnitBucket(item.unitCount, unitFilter)) return false;
      if (
        search &&
        !item.legalName.toLowerCase().includes(search) &&
        !item.city.toLowerCase().includes(search)
      ) {
        return false;
      }
      return true;
    });
  }, [associations, countyFilter, searchFilter, statusFilter, unitFilter]);

  const markers = useMemo(() => {
    if (!projection) return [] as Marker[];

    const seenCoordinates = new Map<string, number>();
    const plotted: Marker[] = [];

    for (const association of filteredAssociations) {
      if (association.latitude === null || association.longitude === null) continue;

      const projected = projection([association.longitude, association.latitude]);
      if (!projected) continue;

      const [x, y] = projected;
      const coordinateKey = `${Math.round(x)}:${Math.round(y)}`;
      const overlapIndex = seenCoordinates.get(coordinateKey) ?? 0;
      seenCoordinates.set(coordinateKey, overlapIndex + 1);

      const ring = Math.floor(overlapIndex / 8) + 1;
      const angle = (overlapIndex % 8) * (Math.PI / 4);
      const offset = overlapIndex === 0 ? { x: 0, y: 0 } : { x: Math.cos(angle) * ring * 5, y: Math.sin(angle) * ring * 5 };

      plotted.push({
        association,
        x: x + offset.x,
        y: y + offset.y,
        radius: Math.min(10, 3 + Math.sqrt(association.unitCount) / 5),
      });
    }

    return plotted;
  }, [filteredAssociations, projection]);

  const selectedAssociation = useMemo(() => {
    if (filteredAssociations.length === 0) return null;
    return (
      filteredAssociations.find((item) => item.id === selectedAssociationId) || filteredAssociations[0]
    );
  }, [filteredAssociations, selectedAssociationId]);

  const riskCount = filteredAssociations.filter(
    (item) => item.complianceStatus === "At Risk" || item.complianceStatus === "Overdue",
  ).length;
  const averageUnits = filteredAssociations.length
    ? Math.round(
        filteredAssociations.reduce((total, item) => total + item.unitCount, 0) /
          filteredAssociations.length,
      )
    : 0;

  const countyBreakdown = useMemo(() => {
    const counts = new Map<string, number>();
    for (const item of filteredAssociations) {
      counts.set(item.county, (counts.get(item.county) ?? 0) + 1);
    }
    return [...counts.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5);
  }, [filteredAssociations]);

  return (
    <section className="map-dashboard reveal delay-1">
      <div className="map-filter-grid">
        <label>
          Compliance Status
          <select
            value={statusFilter}
            onChange={(event) => setStatusFilter(event.target.value as StatusBucket)}
          >
            <option value="All">All statuses</option>
            <option value="Compliant">Compliant</option>
            <option value="At Risk">At Risk</option>
            <option value="Overdue">Overdue</option>
          </select>
        </label>
        <label>
          County
          <select value={countyFilter} onChange={(event) => setCountyFilter(event.target.value)}>
            <option value="All">All counties</option>
            {countyOptions.map((county) => (
              <option key={county} value={county}>
                {county}
              </option>
            ))}
          </select>
        </label>
        <label>
          Unit Size
          <select
            value={unitFilter}
            onChange={(event) => setUnitFilter(event.target.value as UnitBucket)}
          >
            <option value="All">All unit counts</option>
            <option value="25-99">25 to 99 units</option>
            <option value="100-249">100 to 249 units</option>
            <option value="250+">250+ units</option>
          </select>
        </label>
        <label>
          Search Association
          <input
            type="search"
            value={searchFilter}
            onChange={(event) => setSearchFilter(event.target.value)}
            placeholder="Name or city"
          />
        </label>
      </div>

      <div className="map-layout">
        <article className="panel map-panel">
          <svg
            className="fl-map-svg"
            viewBox={`0 0 ${MAP_WIDTH} ${MAP_HEIGHT}`}
            role="img"
            aria-label="Florida association compliance map"
          >
            <rect x={0} y={0} width={MAP_WIDTH} height={MAP_HEIGHT} className="fl-map-ocean" />
            {floridaPath ? <path d={floridaPath} className="fl-map-outline" /> : null}
            {markers.map((marker) => (
              <g key={marker.association.id}>
                <circle
                  className={markerClass(marker.association.complianceStatus)}
                  cx={marker.x}
                  cy={marker.y}
                  r={marker.radius}
                  onClick={() => setSelectedAssociationId(marker.association.id)}
                />
                {selectedAssociation?.id === marker.association.id ? (
                  <circle
                    className="fl-map-marker-focus"
                    cx={marker.x}
                    cy={marker.y}
                    r={marker.radius + 5}
                  />
                ) : null}
              </g>
            ))}
          </svg>
          <div className="map-legend">
            <span>
              <i className="legend-dot legend-good" /> Compliant
            </span>
            <span>
              <i className="legend-dot legend-warn" /> At Risk
            </span>
            <span>
              <i className="legend-dot legend-bad" /> Overdue
            </span>
            <span>
              Showing {markers.length} mapped points ({filteredAssociations.length - markers.length} with no
              coordinates)
            </span>
          </div>
        </article>

        <aside className="map-side">
          <div className="stats-grid map-stats-grid">
            <article className="metric-card">
              <span>Filtered Associations</span>
              <strong>{filteredAssociations.length}</strong>
              <small>Live result set</small>
            </article>
            <article className="metric-card">
              <span>Risk Exposure</span>
              <strong>{riskCount}</strong>
              <small>At Risk + Overdue</small>
            </article>
            <article className="metric-card">
              <span>Avg Unit Count</span>
              <strong>{averageUnits}</strong>
              <small>Per filtered association</small>
            </article>
            <article className="metric-card">
              <span>County Reach</span>
              <strong>{new Set(filteredAssociations.map((item) => item.county)).size}</strong>
              <small>Counties represented</small>
            </article>
          </div>

          <article className="panel">
            <div className="panel-head">
              <h2>Selected Association</h2>
            </div>
            {selectedAssociation ? (
              <div className="map-selected">
                <p className="map-selected-name">{selectedAssociation.legalName}</p>
                <p>
                  {selectedAssociation.city}, {selectedAssociation.state} · {selectedAssociation.county} County
                </p>
                <div className="chips-row">
                  <span className={statusPillClass(selectedAssociation.complianceStatus)}>
                    {selectedAssociation.complianceStatus}
                  </span>
                  <span className="pill">{selectedAssociation.unitCount} units</span>
                  {selectedAssociation.zip ? <span className="pill">ZIP {selectedAssociation.zip}</span> : null}
                </div>
                <Link className="button-link" href={`/condos/${selectedAssociation.id}`}>
                  Open profile
                </Link>
              </div>
            ) : (
              <p>No associations match your current filters.</p>
            )}
          </article>

          <article className="panel">
            <div className="panel-head">
              <h2>County Breakdown</h2>
            </div>
            {countyBreakdown.length > 0 ? (
              <ul className="stack-list">
                {countyBreakdown.map(([county, count]) => (
                  <li key={county}>
                    <p>{county}</p>
                    <span>{count}</span>
                  </li>
                ))}
              </ul>
            ) : (
              <p>No county data for this filter set.</p>
            )}
          </article>
        </aside>
      </div>
    </section>
  );
}
