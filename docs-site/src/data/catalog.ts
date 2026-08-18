export interface BundleInfo {
  name: string;
  package: string;
  version: string | null;
  description: string | null;
  descriptionZh: string | null;
  homepage: string | null;
}

export interface PresetInfo {
  name: string;
  package: string;
  defaultProfile: string | null;
  profiles: string[];
  bundles: string[];
  description: string | null;
  descriptionZh: string | null;
  homepage: string | null;
}

export interface Catalog {
  bundles: BundleInfo[];
  presets: PresetInfo[];
}

export { catalog } from './catalog.generated';
