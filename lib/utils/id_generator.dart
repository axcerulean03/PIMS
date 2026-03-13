class IDGenerator {
  static String generateWFP(int year, int count) {
    return "WFP-$year-${count.toString().padLeft(4, '0')}";
  }

  static String generateActivity(String wfpId, int count) {
    return "ACT-$wfpId-${count.toString().padLeft(2, '0')}";
  }
}
