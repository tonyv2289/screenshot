declare module "zipcodes" {
  export type ZipRecord = {
    zip: string;
    latitude: number;
    longitude: number;
    city: string;
    state: string;
    country: string;
  };

  const zipcodes: {
    lookup: (zip: string) => ZipRecord | null;
  };

  export default zipcodes;
}
