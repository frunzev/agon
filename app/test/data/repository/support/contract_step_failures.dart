typedef ContractStep = Future<void> Function();

typedef StepOutcome<Result> = ({Result? value, Object? failure});

Future<Object?> findStepFailure(ContractStep step) async {
  try {
    await step();
  } on Object catch (error) {
    return error;
  }
  return null;
}

bool isContractRefusal(Object? failure) {
  return failure is StateError || failure is ArgumentError;
}

Future<StepOutcome<Result>> runContractStep<Result>(
  Future<Result> Function() step,
) async {
  try {
    final Result value = await step();
    return (value: value, failure: null);
  } on Object catch (error) {
    return (value: null, failure: error);
  }
}
