{% from 'allowed_states.map.jinja' import allowed_states %}
{% if sls in allowed_states %}

include:
  - ca.dirs

{% set manager = salt['grains.get']('master') %}
/etc/salt/minion.d/signing_policies.conf:
  file.managed:
    - source: salt://ca/files/signing_policies.conf

pki_private_ca_key:
  x509.private_key_managed:
    - name: /etc/pki/ca.key
    - bits: 4096
    - passphrase:
    - cipher: aes_256_cbc
    - backup: True
    {% if salt['file.file_exists']('/etc/pki/ca.key') -%}
    - prereq:
      - x509: /etc/pki/ca.crt
    {%- endif %}

pki_public_ca_crt:
  x509.certificate_managed:
    - name: /etc/pki/ca.crt
    - signing_private_key: /etc/pki/ca.key
    - CN: {{ manager }}
    - C: US
    - ST: Utah
    - L: Salt Lake City
    - basicConstraints: "critical CA:true"
    - keyUsage: "critical cRLSign, keyCertSign"
    - extendedkeyUsage: "serverAuth, clientAuth"
    - subjectKeyIdentifier: hash
    - authorityKeyIdentifier: keyid,issuer:always
    - days_valid: 3650
    - days_remaining: 0
    - backup: True
    - replace: False
    - require:
      - sls: ca.dirs
    - timeout: 30
    - retry:
        attempts: 5
        interval: 30

ca_crt_to_mine:
  module.run:
    - mine.send:
       - name: x509.get_pem_entries
       - glob_path: /etc/pki/ca.crt
    - onchanges:
      - x509: pki_public_ca_crt

orchestrate_ssl_update:
  salt.runner:
    - name: state.orchestrate
    - kwarg:
        mods: _orchestrate.ssl.update
    - onchanges:
      - x509: pki_public_ca_crt


cakeyperms:
  file.managed:
    - replace: False
    - name: /etc/pki/ca.key
    - mode: 640
    - group: 939

{% else %}

{{sls}}_state_not_allowed:
  test.fail_without_changes:
    - name: {{sls}}_state_not_allowed

{% endif %}
