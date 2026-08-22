start_all()

# machine: no source/sink ⇒ no pipeline ⇒ the collector must NOT be enabled
# (a pipeline-less collector fails to start). Assert the unit was not created.
machine.fail("systemctl is-active opentelemetry-collector.service")
machine.fail("systemctl cat opentelemetry-collector.service")
print("No-pipeline machine: collector not enabled (guard works)")

# pipeline: complete logs pipeline ⇒ collector starts and stays running.
pipeline.wait_for_unit("opentelemetry-collector.service")
pipeline.succeed("systemctl is-active opentelemetry-collector.service")
print("Pipeline machine: collector enabled")
print("Collector guard test passed!")