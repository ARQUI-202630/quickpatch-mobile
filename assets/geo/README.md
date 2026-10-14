# Localidades de Bogotá D.C.

`localidades_bogota.geojson` tiene los límites de las 20 localidades para el mapa de cobertura del técnico (SCRUM-89).
Cada elemento solo lleva `codigo` (`01` Usaquén … `20` Sumapaz), el mismo `code` de `GET /v1/localities`
(`matching.v1.yaml`); los nombres vienen de la API.

- **Fuente:** capa «Localidad. Bogotá D.C.», Secretaría Distrital de Planeación, publicada por IDECA en
  [Datos Abiertos Bogotá](https://datosabiertos.bogota.gov.co/dataset/localidad-bogota-d-c) (recurso GeoJSON `loca.json`,
  descargado el 2026-10-14).
- **Licencia:** [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). La app muestra la atribución debajo del mapa.
- **Coordenadas:** MAGNA-SIRGAS (EPSG:4686), longitud y latitud; a esta escala equivale a WGS84.

## Cómo se generó

1. El recurso viene en formato Esri JSON (`rings`). Se convirtió a GeoJSON con solo el campo `codigo`
   (de `LocCodigo`). Santa Fe conserva su hueco, que es La Candelaria.
2. Se simplificó con [mapshaper](https://github.com/mbloch/mapshaper) 0.6.102, que preserva las fronteras
   compartidas entre localidades:

   ```sh
   npx mapshaper localidades-completo.geojson -simplify interval=30 keep-shapes -clean \
     -o localidades_bogota.geojson precision=0.00001 format=geojson
   ```

   El original pesa 2.2 MB (unos 58 000 puntos); simplificado a 30 m pesa 92 KB sin diferencias visibles en la app.
