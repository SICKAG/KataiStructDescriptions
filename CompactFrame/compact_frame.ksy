meta:
  id: compact_frame
  endian: le
  bit-endian: be
seq:
  - id: header
    type: compactheader
  - id: module
    if: header.next_module_size > 0
    type: compactmodule
    repeat: until
    repeat-until: _.metadata.next_module_size == 0
  - id: checksum
    type: u4
    doc: >
         The CRC32 checksum that follows the payload is calculated over the entire data package,
         i.e., over the header and the serialized scan segment.
types:
  compactheader:
    seq:
      - id: magic
        contents: [0x02, 0x02, 0x02, 0x02]
      - id: command_id
        type: u4
        doc: Type of the transmitted telegram. To transmit primary data, the commandId is 1.
      - id: telegram_counter
        type: u8
        doc: Counts all telegrams sent since the device was switched on. The counter starts at 1.
      - id: timestamp_transmit
        type: u8
        doc: >
             Sensor system time in US since 1.1.1970 00:00 in UTC.
      - id: telegram_version
        type: u4
        doc: Version of the telegram with the commandId used.
        valid:
          min: 3
          max: 4
      - id: next_module_size
        type: u4
        doc: Size of the first module to be read.
  compactmodule:
    seq:
      - id: metadata
        type: metadata
      - id: beams
        type: beam
        repeat: expr
        repeat-expr: metadata.num_beams_per_scan
        doc: >
          First, a List with entries for beams is created, which has the length metadata.num_beams_per_scan.
          Then metadata.num_lines_in_module entries are made for each beam, which contain the line information (echo etc.).

  metadata:
    seq:
      - id: segment_counter
        type: u8
      - id: frame_number
        type: u8
        doc: Counts the number of full revolutions since the device was started.
      - id: sender_id
        type: u4
        doc: Device serial number. It can be used to detect on the recipient which sensor the data was sent from.
      - id: num_lines_in_module
        type: u4
        doc: Number of layers contained in one module
      - id: num_beams_per_scan
        type: u4
        doc: Number of beams per scan from one layer. Scans from all layers in a module have the same number of beams.
      - id: num_echos_per_beam
        type: u4
        doc: Number of echoes per beam
      - id: timestamp_start
        type: u8
        repeat: expr
        repeat-expr: num_lines_in_module
        doc: >
             Array of acquisition times for the first beam of each scan in the current module in us.
             The device's internal time base is used or, if the sensor offers the feature, the time set externally.
      - id: timestamp_stop
        type: u8
        repeat: expr
        repeat-expr: num_lines_in_module
        doc: >
             Array of acquisition times for the last beam of each scan in the current module in us.
             The device's internal time base is used or, if the sensor offers the feature, the time set externally.
      - id: phi
        type: f4
        repeat: expr
        repeat-expr: num_lines_in_module
        doc: Array of elevation angles in radians of each layer in the current module.
      - id: theta_start
        type: f4
        repeat: expr
        repeat-expr: num_lines_in_module
        doc: Array of azimuth angles in radians for the first beam of each scan of a layer in the current module.
      - id: theta_stop
        type: f4
        repeat: expr
        repeat-expr: num_lines_in_module
        doc: Array of azimuth angles in radians for the last beam of each scan of a layer in the current module.
      - id: distance_scaling_factor
        if: _parent._parent.header.telegram_version >= 4
        type: f4
        doc: >
             This factor is used to scale the distance values in the beam data to be able to
             represent values above 65535mm with 16Bits or alternatively a sub-millimeter resolution.
      - id: next_module_size
        type: u4
        doc: Size of the next module, or 0 if the current module is the last one.
      - id: reserved
        type: u1
      - id: data_content_echos
        type: data_content_echos
        doc: Describes which data is avaible in every measurement_data e.g distance or RSSI
      - id: data_content_beams
        type: data_content_beams
        doc: Describes which data is measured once in eah measurement_data e.g Azimuth or beam_properties 
      - id: reserved1
        type: u1
    instances:
      theta_start_deg:
        value: theta_start[0]  * 180.0 / 3.141592653589
      theta_stop_deg:
        value: theta_stop[0]  * 180.0 / 3.141592653589
  data_content_echos:
    seq:
      - id: reserved
        type: b6
      - id: rssi
        type: b1
      - id: distance
        type: b1
  data_content_beams:
    seq:
      - id: reserved
        type: b6
      - id: azimuth_angles
        type: b1
      - id: beam_properties
        type: b1
  beam:
    seq:
      - id: lines
        type: measurement_data
        repeat: expr
        repeat-expr: _parent.metadata.num_lines_in_module
  measurement_data:
    seq:
      - id: echos
        type: echo
        repeat: expr
        repeat-expr: _parent._parent.metadata.num_echos_per_beam
      - id: theta_3
        if: _parent._parent.metadata.data_content_beams.azimuth_angles and (_parent._parent._parent.header.telegram_version < 4)
        type: u2
        doc: For telegram version 3, the theta field is serialized before the properties (see errata).
        doc-ref: https://supportportal.sick.com/trouble-shooting/multiscan-v111-twist-compact-data-format/
      - id: properties
        if: _parent._parent.metadata.data_content_beams.beam_properties
        type: beam_properties
      - id: theta_4
        if: _parent._parent.metadata.data_content_beams.azimuth_angles and (_parent._parent._parent.header.telegram_version >= 4)
        type: u2
        doc: For telegram version 4, the theta field is serialized after the properties field.
    instances:
      theta:
        value: '_parent._parent._parent.header.telegram_version >= 4 ? theta_4 : theta_3'
        doc: Azimuth angle, a_rad = (a_uint - 16384)/ 5215
      theta_rad:
        value: (theta.as<f4> - 16384.0) / 5215.0
      theta_deg:
        value: theta_rad * 180.0 / 3.141592653589
  echo:
    seq:
      - id: distance_raw
        if: _parent._parent._parent.metadata.data_content_echos.distance
        type: u2
        doc: Raw distance scaled with distance_scaling_factor
      - id: rssi
        if: _parent._parent._parent.metadata.data_content_echos.rssi
        type: u2
        doc: >
             The RSSI is a dimensionless quantity. The values can fall within the complete value range between 0 and (2^16)-1,
             whereby it is possible that the maximum value is rarely or even never reached.
             The RSSI is generally also not standardized and therefore not exactly comparable between devices.
    instances:
      distance:
        value: '_parent._parent._parent._parent.header.telegram_version >= 4 ? _parent._parent._parent.metadata.distance_scaling_factor * distance_raw : distance_raw'
        doc: Distance in mm
  beam_properties:
    seq:
      - id: reserved
        type: b7
      - id: reflector
        type: b1

